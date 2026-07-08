import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/account_type_screen.dart';
import 'screens/validate_account_screen.dart';
import 'screens/recover_password_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/car_detail_screen.dart';
import 'screens/confirm_booking_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/reservation_detail_screen.dart';
import 'services/reservation_service.dart';
import 'screens/messages_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/owner_main_screen.dart';
import 'screens/owner_earnings_screen.dart';
import 'screens/owner_reservation_history_screen.dart';
import 'screens/report_issue_screen.dart';
import 'screens/rate_reservation_screen.dart';
import 'screens/withdrawal_history_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/help_screen.dart';
import 'screens/favorites_screen.dart';
import 'services/auth_service.dart';
import 'models/vehicle_models.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';


const String kStripePublishableKey = String.fromEnvironment(
  'STRIPE_PUBLISHABLE_KEY',
  defaultValue:
      'pk_test_51Th2unJzufJTi3cmRVyqzL0RGDe1fxxjL6v0en5nB1YE63CEZYUeJMKMMgEFnPhoGA2q1YgGxMI6FkBxY2Q7qzcQ00QJmxasJ8',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // reservation_detail_screen.dart (Box 2) shows dates like "Lun 06 jul 2026"
  // via DateFormat(..., 'es') (formatReservationDayLabel in
  // reservation_service.dart), which needs the 'es' locale's date symbol
  // data loaded before first use or it throws a LocaleDataException.
  await initializeDateFormatting('es');
  await Hive.initFlutter();
  await Hive.openBox('register_draft');
  await Hive.openBox('user_docs');
  await Hive.openBox('user_profile');
  await Hive.openBox('conversations_map');
  // flutter_stripe only supports Android/iOS (it calls Platform.operatingSystem
  // internally, which throws unconditionally on web) — this app targets mobile
  // only, so Stripe init is skipped entirely on web rather than attempted.
  if (!kIsWeb) {
    Stripe.publishableKey = kStripePublishableKey;
    await Stripe.instance.applySettings();
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const Rent2GoApp());
}

class Rent2GoApp extends StatelessWidget {
  const Rent2GoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Rent2Go',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          surface: Color(0xFF16213E),
        ),
      ),
      routerConfig: _router,
    );
  }
}

const _renterPaths = ['/home', '/bookings', '/messages', '/profile', '/car-detail', '/confirm-booking', '/favorites'];
const _ownerPaths = ['/owner'];
// Rutas compartidas por ambos roles (no se redirigen): '/reservation-detail',
// '/chat', '/verify-identity' — se abren tanto desde pantallas de renter como
// de owner (bookings_screen.dart y owner_dashboard_screen.dart respectivamente).

final _router = GoRouter(
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('is_logged_in') ?? false;
    final path = state.uri.path;
    final publicPaths = ['/login', '/register', '/account-type', '/validate', '/recover', '/terms', '/help'];

    if (!loggedIn) {
      if (!publicPaths.any((p) => path.startsWith(p))) return '/login';
      return null;
    }

    final accountType = await AuthService.getAccountType();

    if (accountType == 'OWNER' && _renterPaths.any((p) => path.startsWith(p))) {
      return '/owner';
    }
    if (accountType == 'RENTER' && _ownerPaths.any((p) => path.startsWith(p))) {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', redirect: (_, __) async => '/login'),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/account-type', builder: (_, __) => const AccountTypeScreen()),
    GoRoute(path: '/validate', builder: (_, __) => const ValidateAccountScreen()),
    GoRoute(path: '/recover', builder: (_, __) => const RecoverPasswordScreen()),

    GoRoute(path: '/home', builder: (_, __) => const ExploreScreen()),
    GoRoute(path: '/bookings', builder: (_, __) => const BookingsScreen()),
    GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
    GoRoute(
      path: '/car-detail',
      builder: (context, state) => CarDetailScreen(vehicle: state.extra as VehicleData),
    ),
    GoRoute(
      path: '/confirm-booking',
      builder: (context, state) => ConfirmBookingScreen(vehicle: state.extra as VehicleData),
    ),
    GoRoute(
      path: '/reservation-detail',
      builder: (context, state) => ReservationDetailScreen(reservation: state.extra as ReservationData),
    ),
    GoRoute(
      path: '/verify-identity',
      builder: (context, state) => const ValidateAccountScreen(reVerifyMode: true),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ChatScreen(
          name: extra['name'] as String,
          car: extra['car'] as String,
          isOnline: extra['isOnline'] as bool,
          ownerId: extra['ownerId'] as int,
          renterId: extra['renterId'] as int,
          vehicleId: extra['vehicleId'] as int?,
          reservationId: extra['reservationId'] as int?,
          counterpartyPhotoUrl: extra['counterpartyPhotoUrl'] as String?,
        );
      },
    ),

    GoRoute(path: '/owner', builder: (_, __) => const OwnerMainScreen()),
    GoRoute(
      path: '/owner/earnings',
      builder: (context, __) => OwnerEarningsScreen(
        onBack: () => context.go('/owner'),
      ),
    ),
    GoRoute(path: '/owner/reservation-history', builder: (_, __) => const OwnerReservationHistoryScreen()),
    GoRoute(path: '/owner/withdrawal-history', builder: (_, __) => const WithdrawalHistoryScreen()),

    GoRoute(
      path: '/report-issue',
      builder: (context, state) => ReportIssueScreen(reservation: state.extra as ReservationData),
    ),
    GoRoute(
      path: '/rate-reservation',
      builder: (context, state) => RateReservationScreen(reservation: state.extra as ReservationData),
    ),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),

    GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
    GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
  ],
);
