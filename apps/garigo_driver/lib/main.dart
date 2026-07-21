import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gari_api/gari_api.dart';
import 'package:gari_core/gari_core.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pick_upload.dart';

part 'driver_screens.dart';

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

const _drvTok = 'drv_tok';

ApprovalStatus _approval(dynamic v) {
  final s = v?.toString() ?? 'none';
  return ApprovalStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => ApprovalStatus.none,
  );
}

OnlineStatus _online(dynamic v) {
  final s = v?.toString() ?? 'offline';
  if (s == 'on_trip') return OnlineStatus.onTrip;
  return OnlineStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => OnlineStatus.offline,
  );
}

VehicleCategory? _catOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  for (final e in VehicleCategory.values) {
    if (e.name == s) return e;
  }
  return null;
}

Driver driverFromJson(Map<String, dynamic> m, {Map<String, dynamic>? vehicle}) {
  return Driver(
    id: m['id'].toString(),
    phone: m['phone']?.toString() ?? '',
    name: m['name']?.toString(),
    rating: _asDouble(m['rating_avg'], 5),
    approvalStatus: _approval(m['approval_status']),
    vehicleCategory: _catOrNull(m['category']),
    onlineStatus: _online(m['online_status']),
    commissionPercent: _asDouble(m['commission_percent'], 15),
    totalTrips: _asInt(m['total_trips']),
    plate: vehicle?['plate_number']?.toString() ?? m['plate']?.toString(),
    vehicleColor: vehicle?['color']?.toString() ?? m['vehicle_color']?.toString(),
    vehicleModel: vehicle?['model']?.toString() ?? m['vehicle_model']?.toString(),
    rejectionReasons: (m['rejection_reasons'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    lat: _asDouble(m['lat'], 9.0222),
    lng: _asDouble(m['lng'], 38.7468),
  );
}

double _asDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

int _asInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.round();
  return int.tryParse(v.toString()) ??
      double.tryParse(v.toString())?.round() ??
      fallback;
}

class DriverApi {
  DriverApi(this.prefs, this.secure, {String? token})
      : client = GariApiClient(token: token);

  final SharedPreferences prefs;
  final FlutterSecureStorage secure;
  final GariApiClient client;

  Driver? driver;
  int balance = 0;
  int debt = 0;
  PayoutMethod? payout;
  final docs = <DocumentType, DriverDocument>{};

  Future<String?> token() async {
    final s = await secure.read(key: _drvTok);
    if (s != null && s.isNotEmpty) return s;
    return prefs.getString(_drvTok);
  }

  Future<void> _persistTok(String tok) async {
    await secure.write(key: _drvTok, value: tok);
    await prefs.setString(_drvTok, tok);
    client.setToken(tok);
  }

  Future<void> setLocale(String c) => prefs.setString('locale', c);
  String? get locale => prefs.getString('locale');

  Future<void> requestOtp(String phone) async {
    await client.requestOtp(phone: phone, role: 'driver');
  }

  Future<Driver> verify(String phone, String code, {String? name}) async {
    final res = await client.verifyOtp(
      phone: phone,
      code: code,
      role: 'driver',
      name: name,
    );
    final tok = res['token']?.toString();
    final raw = Map<String, dynamic>.from(res['driver'] as Map);
    driver = driverFromJson(raw);
    if (tok != null) {
      await _persistTok(tok);
      client.connectSocket(role: 'driver', userId: driver!.id);
    }
    await refreshEarnings();
    return driver!;
  }

  Future<void> restore() async {
    final t = await token();
    if (t == null) return;
    client.setToken(t);
    try {
      final me = await client.me();
      final profile = Map<String, dynamic>.from(me['profile'] as Map);
      driver = driverFromJson(profile);
      client.connectSocket(role: 'driver', userId: driver!.id);
      await syncDocsFromServer();
      await refreshEarnings();
    } catch (_) {
      await logout();
    }
  }

  Future<void> logout() async {
    client.disconnectSocket();
    await secure.delete(key: _drvTok);
    await prefs.remove(_drvTok);
    client.setToken(null);
    driver = null;
    balance = 0;
    debt = 0;
    docs.clear();
  }

  Future<void> setOnline(bool online) async {
    await client.setOnline(online);
    if (driver != null) {
      driver = driver!.copyWith(
        onlineStatus: online ? OnlineStatus.online : OnlineStatus.offline,
      );
    }
    if (online) {
      await client.pushLocation(
        lat: driver?.lat ?? 9.010,
        lng: driver?.lng ?? 38.780,
      );
    }
  }

  Future<void> refreshEarnings() async {
    try {
      final res = await client.driverEarnings();
      final bal = Map<String, dynamic>.from(res['balance'] as Map? ?? {});
      balance = (bal['available_balance'] as num?)?.round() ?? 0;
      debt = (bal['cash_debt'] as num?)?.round() ?? 0;
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> earningsTrips() async {
    final res = await client.driverEarnings();
    return (res['trips'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> setVehicle(VehicleCategory c) async {
    await client.setVehicleCategory(c.name);
    driver = driver?.copyWith(vehicleCategory: c);
  }

  Future<void> saveVehicleDetails({
    required VehicleCategory category,
    required String plate,
    String? make,
    String? model,
    String? color,
    required bool isOwner,
    String? name,
    String? tin,
    String? businessReg,
    String? licenseNumber,
    String? nationalId,
  }) async {
    await client.saveDriverVehicle({
      'category': category.name,
      'plateNumber': plate,
      'make': make,
      'model': model,
      'color': color,
      'isVehicleOwner': isOwner,
      'name': name,
      'tinNumber': tin,
      'businessRegNumber': businessReg,
      'licenseNumber': licenseNumber,
      'nationalIdNumber': nationalId,
    });
    driver = driver?.copyWith(vehicleCategory: category, name: name);
    seedDocs(category, isOwner: isOwner);
  }

  Future<void> setPayout(PayoutMethodType t, String details) async {
    final type = switch (t) {
      PayoutMethodType.telebirr => 'telebirr',
      PayoutMethodType.cbeBirr => 'cbe_birr',
      PayoutMethodType.helloCash => 'hellocash',
    };
    await client.setPayoutMethod(type: type, details: details);
    payout = PayoutMethod(type: t, details: details);
  }

  Future<void> submitApproval({
    String? name,
    String? tinNumber,
    String? businessRegNumber,
  }) async {
    await client.submitForApproval(
      name: name,
      tinNumber: tinNumber,
      businessRegNumber: businessRegNumber,
    );
    driver = driver?.copyWith(approvalStatus: ApprovalStatus.pending);
  }

  DocumentType? _typeFromApi(String key) {
    for (final t in DocumentType.values) {
      if (t.apiKey == key) return t;
    }
    return null;
  }

  void seedDocs(VehicleCategory c, {bool isOwner = true}) {
    docs.clear();
    void a(DocumentType t) => docs[t] = DriverDocument(
          type: t,
          nameEn: t.labelEn,
          nameAm: t.labelEn,
        );
    a(DocumentType.selfie);
    a(DocumentType.nationalIdFront);
    a(DocumentType.licenseFront);
    a(DocumentType.vehicleFront);
    a(DocumentType.vehicleBack);
    a(DocumentType.vehicleLeft);
    a(DocumentType.vehicleRight);
    a(DocumentType.vehicleLibre);
    a(DocumentType.tinCertificate);
    a(DocumentType.businessRegistration);
    if (!isOwner) a(DocumentType.ownerAuthorization);
    if (c == VehicleCategory.moto) a(DocumentType.helmetVest);
  }

  Future<void> syncDocsFromServer() async {
    try {
      final res = await client.listDriverDocuments();
      final required = List<String>.from(res['required'] as List? ?? const []);
      final cat = driver?.vehicleCategory ?? VehicleCategory.car;
      final isOwner =
          (res['driver'] as Map?)?['is_vehicle_owner'] != false;
      seedDocs(cat, isOwner: isOwner);
      for (final key in required) {
        final t = _typeFromApi(key);
        if (t != null && !docs.containsKey(t)) {
          docs[t] = DriverDocument(
            type: t,
            nameEn: t.labelEn,
            nameAm: t.labelEn,
          );
        }
      }
      final list = List<dynamic>.from(res['documents'] as List? ?? const []);
      for (final raw in list) {
        final m = Map<String, dynamic>.from(raw as Map);
        final t = _typeFromApi(m['docType']?.toString() ?? '');
        if (t == null) continue;
        final rejection = m['rejectionReason']?.toString();
        final verified = m['verified'] == true;
        final DocumentStatus status;
        if (rejection != null && rejection.isNotEmpty) {
          status = DocumentStatus.rejected;
        } else if (verified) {
          status = DocumentStatus.verified;
        } else if ((m['url']?.toString() ?? '').isNotEmpty) {
          status = DocumentStatus.uploaded;
        } else {
          status = DocumentStatus.empty;
        }
        docs[t] = DriverDocument(
          type: t,
          nameEn: m['label']?.toString() ?? t.labelEn,
          nameAm: t.labelEn,
          status: status,
          url: m['url']?.toString(),
          rejectionReason: rejection,
        );
      }
    } catch (_) {}
  }

  Future<void> uploadDoc(DocumentType type, List<int> bytes, String filename) async {
    final res = await client.uploadDriverDocument(
      docType: type.apiKey,
      bytes: bytes,
      filename: filename,
    );
    final doc = Map<String, dynamic>.from(res['document'] as Map);
    docs[type] = DriverDocument(
      type: type,
      nameEn: doc['label']?.toString() ?? type.labelEn,
      nameAm: type.labelEn,
      status: DocumentStatus.uploaded,
      url: doc['url']?.toString(),
      rejectionReason: null,
    );
    // Refresh profile so approval_status can move rejected → pending.
    await restore();
  }
}

String drvErr(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return e.message ?? 'Network error';
  }
  return e.toString();
}

final apiProvider = Provider((ref) =>
    DriverApi(ref.watch(prefsProvider), const FlutterSecureStorage()));

class DAuth {
  const DAuth({
    this.driver,
    this.token,
    this.locale = const Locale('am'),
    this.bootstrapped = false,
  });
  final Driver? driver;
  final String? token;
  final Locale locale;
  final bool bootstrapped;
  bool get isLoggedIn => token != null && driver != null;
  bool get approved => driver?.approvalStatus == ApprovalStatus.approved;
  DAuth copyWith({
    Driver? driver,
    String? token,
    Locale? locale,
    bool? bootstrapped,
    bool clear = false,
  }) =>
      DAuth(
        driver: clear ? null : driver ?? this.driver,
        token: clear ? null : token ?? this.token,
        locale: locale ?? this.locale,
        bootstrapped: bootstrapped ?? this.bootstrapped,
      );
}

class DAuthN extends StateNotifier<DAuth> {
  DAuthN(this.api) : super(const DAuth());
  final DriverApi api;
  Future<void> boot() async {
    await api.restore();
    state = DAuth(
      locale: Locale(api.locale ?? 'am'),
      token: await api.token(),
      driver: api.driver,
      bootstrapped: true,
    );
  }

  Future<void> setLocale(Locale l) async {
    await api.setLocale(l.languageCode);
    state = state.copyWith(locale: l);
  }

  Future<Driver> login(
    String p,
    String c, {
    String? name,
    bool requestOtpFirst = true,
  }) async {
    if (requestOtpFirst) await api.requestOtp(p);
    final d = await api.verify(p, c, name: name);
    final t = await api.token();
    state = state.copyWith(driver: d, token: t);
    return d;
  }

  void upd(Driver d) {
    api.driver = d;
    state = state.copyWith(driver: d);
  }

  Future<void> logout() async {
    await api.logout();
    state = DAuth(locale: state.locale, bootstrapped: true);
  }
}

final authProvider = StateNotifierProvider<DAuthN, DAuth>((ref) => DAuthN(ref.watch(apiProvider)));
final phoneProvider = StateProvider<String>((_) => '');
final offerProvider = StateProvider<TripOffer?>((_) => null);
final activeTripProvider = StateProvider<ActiveTrip?>((_) => null);
final lastFareProvider = StateProvider<FareBreakdown?>((_) => null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final p = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(p)],
    child: const DriverApp(),
  ));
}

class DriverApp extends ConsumerStatefulWidget {
  const DriverApp({super.key});
  @override
  ConsumerState<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends ConsumerState<DriverApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).boot());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.bootstrapped) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: GariColors.nightBlue,
          body: Center(child: CircularProgressIndicator(color: GariColors.amber)),
        ),
      );
    }
    return MaterialApp.router(
      title: 'GariGo Driver',
      debugShowCheckedModeBanner: false,
      theme: GariTheme.light(auth.locale, driverChrome: true),
      locale: auth.locale,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  // Do NOT watch authProvider here — that recreates GoRouter on every
  // profile update and resets navigation (e.g. blocks vehicle → docs).
  final refresh = _R(ref);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (_, state) {
      final auth = ref.read(authProvider);
      if (!auth.bootstrapped) return null;
      final loc = state.matchedLocation;
      if (!auth.isLoggedIn) {
        if (loc == '/' || loc.startsWith('/auth')) return null;
        return '/';
      }
      final st = auth.driver!.approvalStatus;
      if (st == ApprovalStatus.approved) {
        if (loc == '/' ||
            loc.startsWith('/auth') ||
            loc.startsWith('/onboarding')) {
          return '/dashboard';
        }
        return null;
      }
      if (st == ApprovalStatus.pending || st == ApprovalStatus.rejected) {
        if (loc.startsWith('/onboarding') || loc.startsWith('/auth')) {
          return null;
        }
        return '/onboarding/status';
      }
      // approval none — allow every /onboarding/* step (vehicle → docs → …)
      if (st == ApprovalStatus.none) {
        if (loc.startsWith('/onboarding') || loc.startsWith('/auth')) {
          return null;
        }
        return '/onboarding/vehicle';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _Lang()),
      GoRoute(path: '/auth/phone', builder: (_, __) => const _Phone()),
      GoRoute(path: '/auth/otp', builder: (_, __) => const _Otp()),
      GoRoute(path: '/auth/apply', builder: (_, __) => const _DriverApply()),
      GoRoute(path: '/onboarding/vehicle', builder: (_, __) => const _Vehicle()),
      GoRoute(path: '/onboarding/docs', builder: (_, __) => const _Docs()),
      GoRoute(path: '/onboarding/selfie', builder: (_, __) => const _Selfie()),
      GoRoute(path: '/onboarding/payout', builder: (_, __) => const _Payout()),
      GoRoute(path: '/onboarding/training', builder: (_, __) => const _Train()),
      GoRoute(path: '/onboarding/status', builder: (_, __) => const _Status()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, sh) => _Shell(shell: sh),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (_, __) => const _Dash()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/earnings', builder: (_, __) => const _Earn(), routes: [
              GoRoute(path: 'cashout', builder: (_, __) => const _Cash()),
            ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/trips', builder: (_, __) => const _Trips()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const _Prof()),
          ]),
        ],
      ),
      GoRoute(path: '/trip/:id/pickup', builder: (_, s) => _Pickup(id: s.pathParameters['id']!)),
      GoRoute(path: '/trip/:id/pin', builder: (_, s) => _Pin(id: s.pathParameters['id']!)),
      GoRoute(path: '/trip/:id/active', builder: (_, s) => _Active(id: s.pathParameters['id']!)),
      GoRoute(path: '/trip/:id/done', builder: (_, s) => _Done(id: s.pathParameters['id']!)),
      GoRoute(path: '/trip/:id/dispute', builder: (_, s) => _Dispute(id: s.pathParameters['id']!)),
      GoRoute(path: '/incentives', builder: (_, __) => const _Quest()),
      GoRoute(path: '/documents', builder: (_, __) => const _DocCenter()),
      GoRoute(path: '/support', builder: (_, __) => const _Support()),
      GoRoute(path: '/referral', builder: (_, __) => const _Ref()),
    ],
  );
});

class _R extends ChangeNotifier {
  _R(this.ref) {
    ref.listen<DAuth>(authProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}
