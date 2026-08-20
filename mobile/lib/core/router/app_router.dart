import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/gender_select_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/home/presentation/screens/main_screen.dart';
import '../../features/home/presentation/screens/profile_detail_screen.dart';
import '../../features/calls/presentation/screens/audio_call_screen.dart';
import '../../features/calls/presentation/screens/video_call_screen.dart';
import '../../features/wallet/presentation/screens/recharge_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/listener/presentation/screens/listener_register_full_screen.dart';
import '../../features/listener/presentation/screens/listener_voice_verification_screen.dart';
import '../../features/listener/presentation/screens/listener_main_screen.dart';
import '../../features/listener/presentation/screens/listener_payout_screen.dart';
import '../../features/listener/presentation/screens/listener_help_support_screen.dart';
import '../../features/listener/presentation/screens/listener_support_detail_screen.dart';
import '../../features/listener/presentation/screens/listener_terms_screen.dart';
import '../../features/listener/presentation/screens/listener_privacy_screen.dart';
import '../../features/listener/presentation/screens/listener_under_review_screen.dart';
import '../../features/profile/presentation/screens/account_settings_screen.dart';
import '../../features/profile/presentation/screens/user_terms_screen.dart';
import '../storage/secure_storage.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) async {
    final loc = state.matchedLocation;

    // Always allow splash
    if (loc == '/splash') return null;

    // Always allow auth and listener routes
    if (loc.startsWith('/auth') || loc.startsWith('/listener')) return null;

    // For all other routes, only check if logged in
    final loggedIn = await SecureStorage.isLoggedIn();
    if (!loggedIn) return '/auth/login';

    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
    GoRoute(
      path: '/auth',
      redirect: (context, state) {
        if (state.matchedLocation == '/auth') return '/auth/login';
        return null;
      },
      routes: [
        GoRoute(path: 'login', builder: (c, s) => const LoginScreen()),
        GoRoute(
          path: 'register',
          builder: (c, s) => RegisterScreen(initialGender: s.uri.queryParameters['gender']),
        ),
        GoRoute(path: 'gender', builder: (c, s) => const GenderSelectScreen()),
        GoRoute(
          path: 'profile-setup',
          builder: (c, s) => ProfileSetupScreen(
            gender: s.uri.queryParameters['gender'] ?? 'MALE',
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/home',
      builder: (c, s) => const MainScreen(),
      routes: [
        GoRoute(
          path: 'listener/:id',
          builder: (c, s) => ProfileDetailScreen(listenerId: s.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/call/audio',
      builder: (c, s) => AudioCallScreen(extra: (s.extra as Map<String, dynamic>?) ?? {}),
    ),
    GoRoute(
      path: '/call/video',
      builder: (c, s) => VideoCallScreen(extra: (s.extra as Map<String, dynamic>?) ?? {}),
    ),
    GoRoute(path: '/recharge', builder: (c, s) => const RechargeScreen()),
    GoRoute(path: '/wallet', builder: (c, s) => const WalletScreen()),
    GoRoute(path: '/settings/account', builder: (c, s) => const AccountSettingsScreen()),

    // ── Listener routes ──────────────────────────────────────────────────────
    GoRoute(path: '/listener/register', builder: (c, s) => const ListenerVoiceVerificationScreen()),
    GoRoute(path: '/listener/voice-verify', builder: (c, s) => const ListenerVoiceVerificationScreen()),
    GoRoute(
      path: '/listener/register-full',
      builder: (c, s) => ListenerRegisterFullScreen(audioPath: s.extra as String?),
    ),
    GoRoute(path: '/listener/dashboard', builder: (c, s) => const ListenerMainScreen()),
    GoRoute(path: '/listener/payout', builder: (c, s) => const ListenerPayoutScreen()),
    GoRoute(path: '/listener/under-review', builder: (c, s) => const ListenerUnderReviewScreen()),

    // Help & Support
    GoRoute(path: '/listener/help-support', builder: (c, s) => const ListenerHelpSupportScreen()),
    GoRoute(
      path: '/listener/support/:id',
      builder: (c, s) => ListenerSupportDetailScreen(ticketId: s.pathParameters['id']!),
    ),

    // Legal pages
    GoRoute(path: '/listener/terms',   builder: (c, s) => const ListenerTermsScreen()),
    GoRoute(path: '/listener/privacy', builder: (c, s) => const ListenerPrivacyScreen()),

    // ── User side routes ─────────────────────────────────────────────────────
    // User Help & Support (reuses the same backend /support endpoints)
    GoRoute(path: '/user/help-support', builder: (c, s) => const ListenerHelpSupportScreen()),
    GoRoute(path: '/user/terms',        builder: (c, s) => const UserTermsScreen()),
  ],
);
