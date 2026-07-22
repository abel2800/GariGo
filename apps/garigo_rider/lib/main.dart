import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gari_core/gari_core.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/booking/booking_screens.dart';
import '../features/history/more_screens.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/auth_screens.dart';
import '../features/trip/trip_screens.dart';
import '../features/trip/trip_chat_screen.dart';
import '../shared/providers/providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Don't watch authProvider — recreating GoRouter resets navigation.
  final refresh = _AuthRefresh(ref);
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (!auth.bootstrapped) return null;
      final loc = state.matchedLocation;
      final prefs = ref.read(prefsProvider);
      final hasLocale = prefs.containsKey('locale');

      if (!auth.loggedIn) {
        if (hasLocale && loc == '/') return '/auth/phone';
        if (loc == '/' || loc.startsWith('/auth')) return null;
        return hasLocale ? '/auth/phone' : '/';
      }
      final needsProfile = auth.rider != null &&
          !auth.rider!.isGuest &&
          !auth.rider!.profileComplete;
      // While finishing signup OTP → register, allow otp/register routes.
      if (needsProfile &&
          loc != '/auth/register' &&
          loc != '/auth/otp') {
        return '/auth/register';
      }
      if (auth.loggedIn &&
          (loc == '/' ||
              loc == '/auth/phone' ||
              loc == '/auth/signup')) {
        return needsProfile ? '/auth/register' : '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LanguageScreen()),
      GoRoute(path: '/auth/phone', builder: (_, __) => const PhoneScreen(showHero: true)),
      GoRoute(path: '/auth/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/auth/otp', builder: (_, __) => const OtpScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => RiderShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/wallet/cards/add',
        builder: (_, __) => const AddCardScreen(),
      ),
      GoRoute(
          path: '/booking/destination',
          builder: (_, __) => const DestinationScreen()),
      GoRoute(path: '/booking/stops', builder: (_, __) => const StopsScreen()),
      GoRoute(
          path: '/booking/vehicle-class',
          builder: (_, __) => const VehicleClassScreen()),
      GoRoute(
          path: '/booking/payment', builder: (_, __) => const PaymentScreen()),
      GoRoute(
          path: '/booking/pickup-note',
          builder: (_, __) => const PickupNoteScreen()),
      GoRoute(
          path: '/booking/matching',
          builder: (_, __) => const MatchingScreen()),
      GoRoute(
        path: '/trip/:id/matched',
        builder: (_, s) => MatchedScreen(tripId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trip/:id/in-progress',
        builder: (_, s) => InProgressScreen(tripId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trip/:id/summary',
        builder: (_, s) => SummaryScreen(tripId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trip/:id/rate',
        builder: (_, s) => RateScreen(tripId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/trip/:id/chat',
        builder: (_, s) => TripChatScreen(tripId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/history/:id/receipt',
        builder: (_, s) => ReceiptScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/places', builder: (_, __) => const PlacesScreen()),
      GoRoute(
          path: '/safety/contacts',
          builder: (_, __) => const ContactsScreen()),
      GoRoute(path: '/safety', builder: (_, __) => const SafetyScreen()),
      GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
      GoRoute(path: '/referral', builder: (_, __) => const ReferralScreen()),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this.ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const RiderApp(),
  ));
}

class RiderApp extends ConsumerStatefulWidget {
  const RiderApp({super.key});
  @override
  ConsumerState<RiderApp> createState() => _RiderAppState();
}

class _RiderAppState extends ConsumerState<RiderApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.bootstrapped) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: GariColors.nightBlue,
          body: Center(
              child: CircularProgressIndicator(color: GariColors.amber)),
        ),
      );
    }
    return MaterialApp.router(
      title: 'GariGo Rider',
      debugShowCheckedModeBanner: false,
      theme: GariTheme.light(auth.locale),
      locale: auth.locale,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
