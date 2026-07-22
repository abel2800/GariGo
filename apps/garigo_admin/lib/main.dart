import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:gari_api/gari_api.dart';
import 'package:gari_core/gari_core.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kyc_media_viewer.dart';

part 'admin_pages.dart';

const _tokenKey = 'garigo_admin_jwt';
const _adminIdKey = 'garigo_admin_id';

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final apiProvider = Provider<GariApiClient>((ref) {
  final prefs = ref.watch(prefsProvider);
  final token = prefs.getString(_tokenKey);
  return GariApiClient(token: token);
});

class AdminSession {
  const AdminSession({
    required this.loggedIn,
    this.token,
    this.adminId,
    this.email,
    this.name,
    this.role,
    this.permissions = const [],
    this.hasTotp = false,
    this.photoUrl,
    this.phone,
  });

  final bool loggedIn;
  final String? token;
  final String? adminId;
  final String? email;
  final String? name;
  final String? role;
  final List<String> permissions;
  final bool hasTotp;
  final String? photoUrl;
  final String? phone;

  bool get isCeo => role == 'super_admin' || permissions.contains('*');

  /// Still loading /me after restore from token.
  bool get hydrating => loggedIn && role == null;

  bool can(String perm) =>
      permissions.contains('*') || permissions.contains(perm);

  /// Permission required for a route path (longest prefix wins).
  static String? permForPath(String path) {
    const rules = <(String, String)>[
      ('/settings/staff', '*'),
      ('/settings/roles', '*'),
      ('/settings/security', '*'),
      ('/settings/audit', 'audit'),
      ('/settings/profile', ''),
      ('/call-center', 'booking'),
      ('/drivers', 'drivers'),
      ('/docs', 'docs'),
      ('/trips', 'trips'),
      ('/tickets', 'tickets'),
      ('/pricing', 'pricing'),
      ('/zones', 'zones'),
      ('/promos', 'promos'),
      ('/finance/payouts', 'payouts'),
      ('/finance', 'finance'),
      ('/analytics', 'analytics'),
      ('/kpi', 'analytics'),
      ('/comms/push', 'push'),
      ('/comms/announcements', 'announcements'),
      ('/quests', 'quests'),
      ('/riders', 'riders'),
      ('/ops', 'ops'),
    ];
    for (final (prefix, perm) in rules) {
      if (path == prefix || path.startsWith('$prefix/')) return perm;
    }
    return null;
  }

  bool canAccessPath(String path) {
    if (!loggedIn) return false;
    if (hydrating) return true;
    final perm = permForPath(path);
    if (perm == null || perm.isEmpty) return true;
    if (perm == '*') return isCeo;
    return can(perm);
  }

  String get homePath {
    if (hydrating) return '/ops';
    const preferred = [
      '/ops',
      '/call-center',
      '/drivers/approvals',
      '/docs',
      '/trips',
      '/tickets',
      '/finance',
      '/analytics',
      '/settings/profile',
    ];
    for (final p in preferred) {
      if (canAccessPath(p)) return p;
    }
    return '/settings/profile';
  }
}

class AdminSessionNotifier extends StateNotifier<AdminSession> {
  AdminSessionNotifier(this._prefs, this._api)
      : super(AdminSession(
          loggedIn: _prefs.getString(_tokenKey) != null,
          token: _prefs.getString(_tokenKey),
          adminId: _prefs.getString(_adminIdKey),
        )) {
    if (state.loggedIn) {
      _hydrate();
    }
  }

  final SharedPreferences _prefs;
  final GariApiClient _api;

  Future<void> _hydrate() async {
    try {
      final me = await _api.adminMe();
      state = AdminSession(
        loggedIn: true,
        token: state.token,
        adminId: me['id']?.toString(),
        email: me['email']?.toString(),
        name: me['name']?.toString(),
        role: me['role']?.toString(),
        permissions: List<String>.from(me['permissions'] as List? ?? const []),
        hasTotp: me['hasTotp'] == true,
        photoUrl: me['photoUrl']?.toString(),
        phone: me['phone']?.toString(),
      );
      _connectSocket();
    } catch (_) {
      await logout();
    }
  }

  void _connectSocket() {
    final id = state.adminId;
    if (id == null) return;
    _api.connectSocket(role: 'admin', userId: id);
  }

  Future<void> completeLogin({
    required String token,
    required Map<String, dynamic> admin,
  }) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_adminIdKey, admin['id'].toString());
    _api.setToken(token);
    state = AdminSession(
      loggedIn: true,
      token: token,
      adminId: admin['id']?.toString(),
      email: admin['email']?.toString(),
      name: admin['name']?.toString(),
      role: admin['role']?.toString(),
      permissions: List<String>.from(admin['permissions'] as List? ?? const []),
      hasTotp: admin['hasTotp'] == true,
      photoUrl: admin['photoUrl']?.toString(),
      phone: admin['phone']?.toString(),
    );
    _connectSocket();
  }

  Future<void> logout() async {
    _api.disconnectSocket();
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_adminIdKey);
    _api.setToken(null);
    state = const AdminSession(loggedIn: false);
  }
}

final sessionProvider =
    StateNotifierProvider<AdminSessionNotifier, AdminSession>((ref) {
  return AdminSessionNotifier(ref.watch(prefsProvider), ref.watch(apiProvider));
});

/// Notifies GoRouter when auth changes without recreating the router.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this.ref) {
    ref.listen<AdminSession>(sessionProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}

final authRefreshProvider = Provider<_AuthRefresh>((ref) {
  final n = _AuthRefresh(ref);
  ref.onDispose(n.dispose);
  return n;
});

final opsSnapshotProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (!session.loggedIn) return {};
  final api = ref.watch(apiProvider);
  // Refresh every 8s while watched
  final timer = Timer.periodic(const Duration(seconds: 8), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return api.opsSnapshot();
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUrlStrategy(HashUrlStrategy());
  final p = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(p)],
    child: const AdminApp(),
  ));
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'GariGo Ops',
      debugShowCheckedModeBanner: false,
      theme: GariTheme.light(const Locale('en')),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(authRefreshProvider);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      if (!session.loggedIn && loc != '/login') return '/login';
      if (session.loggedIn && loc == '/login') return session.homePath;
      if (session.loggedIn &&
          !session.hydrating &&
          loc != '/login' &&
          !session.canAccessPath(loc)) {
        return session.homePath;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const _Login()),
      ShellRoute(
        builder: (_, __, child) => _AdminShell(child: child),
        routes: [
          GoRoute(path: '/ops', builder: (_, __) => const _Ops()),
          GoRoute(
              path: '/drivers/approvals',
              builder: (_, __) => const _Approvals()),
          GoRoute(
              path: '/drivers/:id',
              builder: (_, s) =>
                  _DriverDetail(id: s.pathParameters['id']!)),
          GoRoute(
              path: '/docs', builder: (_, __) => const _Documents()),
          GoRoute(
              path: '/riders/:id',
              builder: (_, s) =>
                  _RiderDetail(id: s.pathParameters['id']!)),
          GoRoute(path: '/trips', builder: (_, __) => const _Trips()),
          GoRoute(
              path: '/trips/:id',
              builder: (_, s) =>
                  _TripDetail(id: s.pathParameters['id']!)),
          GoRoute(path: '/tickets', builder: (_, __) => const _Tickets()),
          GoRoute(
              path: '/tickets/:id',
              builder: (_, s) =>
                  _TicketDetail(id: s.pathParameters['id']!)),
          GoRoute(path: '/pricing', builder: (_, __) => const _Pricing()),
          GoRoute(path: '/zones', builder: (_, __) => const _Zones()),
          GoRoute(path: '/promos', builder: (_, __) => const _Promos()),
          GoRoute(path: '/finance', builder: (_, __) => const _Finance()),
          GoRoute(
              path: '/finance/payouts',
              builder: (_, __) => const _Payouts()),
          GoRoute(
              path: '/finance/cash-debt',
              builder: (_, __) => const _CashDebt()),
          GoRoute(
              path: '/analytics', builder: (_, __) => const _Analytics()),
          GoRoute(path: '/kpi', builder: (_, __) => const _Kpi()),
          GoRoute(path: '/comms/push', builder: (_, __) => const _Push()),
          GoRoute(
              path: '/comms/announcements',
              builder: (_, __) => const _Announce()),
          GoRoute(path: '/quests', builder: (_, __) => const _Quests()),
          GoRoute(
              path: '/call-center',
              builder: (_, __) => const _CallCenter()),
          GoRoute(
              path: '/settings/staff',
              builder: (_, __) => const _Staff()),
          GoRoute(
              path: '/settings/profile',
              builder: (_, __) => const _MyProfile()),
          GoRoute(
              path: '/settings/roles', builder: (_, __) => const _Roles()),
          GoRoute(
              path: '/settings/audit', builder: (_, __) => const _Audit()),
          GoRoute(
              path: '/settings/security',
              builder: (_, __) => const _Security()),
        ],
      ),
    ],
  );
});

String _err(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return e.message ?? 'Network error';
  }
  return e.toString();
}
