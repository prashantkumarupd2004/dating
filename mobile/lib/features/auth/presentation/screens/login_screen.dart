import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/wallet_provider.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../debug/debug_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String _status = '';   // step-by-step status shown to user

  void _setStatus(String msg) {
    debugPrint('[LOGIN] $msg');
    if (mounted) setState(() => _status = msg);
  }

  void _showError(String msg) {
    debugPrint('[LOGIN ERROR] $msg');
    if (!mounted) return;
    setState(() { _loading = false; _status = ''; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _status = 'Opening Google...'; });
    try {
      // ── Step 1: Google account picker ─────────────────────────────
      _setStatus('Waiting for Google account...');
      final googleSignIn = GoogleSignIn();

      // Sign out first to always show account picker
      await googleSignIn.signOut();

      final gUser = await googleSignIn.signIn();
      if (gUser == null) {
        // User cancelled — not an error
        setState(() { _loading = false; _status = ''; });
        return;
      }
      _setStatus('Google account selected ✓');

      // ── Step 2: Get Google auth tokens ────────────────────────────
      _setStatus('Getting authentication tokens...');
      final gAuth = await gUser.authentication;
      if (gAuth.idToken == null) {
        _showError('Google sign-in failed: Could not get ID token.\n\nPlease try again.');
        return;
      }
      _setStatus('Tokens received ✓');

      // ── Step 3: Firebase sign-in ──────────────────────────────────
      _setStatus('Signing in with Firebase...');
      final cred = GoogleAuthProvider.credential(
        idToken: gAuth.idToken,
        accessToken: gAuth.accessToken,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      if (userCred.user == null) {
        _showError('Firebase sign-in failed. Please try again.');
        return;
      }
      _setStatus('Firebase sign-in successful ✓');

      // ── Step 4: Get Firebase ID token ─────────────────────────────
      _setStatus('Getting server token...');
      final idToken = await userCred.user!.getIdToken(true); // force refresh
      if (idToken == null || idToken.isEmpty) {
        _showError('Failed to get server token. Please try again.');
        return;
      }
      _setStatus('Server token ready ✓');

      // ── Step 5: Call backend API ──────────────────────────────────
      _setStatus('Connecting to server...');
      final resp = await api.post(
        ApiEndpoints.authGoogle,
        data: {'firebaseToken': idToken},
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        final msg = resp.data['message'] ?? 'Server error';
        _showError('Login failed: $msg');
        return;
      }
      _setStatus('Server login successful ✓');

      // ── Step 6: Save tokens ───────────────────────────────────────
      _setStatus('Saving session...');
      final data = resp.data['data'];

      // Save all data synchronously to cache first
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final userId = data['user']['id'] as String;

      // Write to cache AND disk
      await SecureStorage.saveTokens(accessToken, refreshToken);
      await SecureStorage.saveUserId(userId);

      // Always set profile complete as true - skip registration
      await SecureStorage.setProfileComplete(true);

      // Verify cache is set before proceeding
      final verifyLoggedIn = await SecureStorage.isLoggedIn();

      if (!verifyLoggedIn) {
        _showError('Session save failed - cache not set. Please try again.');
        return;
      }

      _setStatus('Session saved ✓');

      // ── Step 7: Initialize session manager ────────────────────────
      await sessionManager.initialize();

      // ── Step 8: Connect socket ────────────────────────────────────
      socketService.connect(); // fire and forget

      // ── Step 9: Initialize wallet balance ─────────────────────────
      walletProvider.fetchBalance(); // Load balance immediately after login

      // ── Step 10: Navigate ──────────────────────────────────────────
      if (!mounted) return;

      // Clear loading state
      setState(() {
        _loading = false;
        _status = '';
      });

      // Small delay for setState to complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Check mounted again after delay
      if (!mounted) return;

      // Always go to home - skip registration
      context.replace('/home');

    } on FirebaseAuthException catch (e) {
      debugPrint('[LOGIN] FirebaseAuthException: ${e.code} — ${e.message}');
      String msg;
      switch (e.code) {
        case 'sign_in_failed':
          msg = 'Google sign-in failed.\n\nMake sure you have internet and try again.';
          break;
        case 'network-request-failed':
          msg = 'No internet connection.\n\nCheck your WiFi/mobile data and try again.';
          break;
        case 'invalid-credential':
          msg = 'Invalid Google credentials.\n\nPlease sign out of Google and try again.';
          break;
        case 'user-disabled':
          msg = 'This account has been disabled.\n\nContact support.';
          break;
        default:
          msg = 'Sign-in error (${e.code}): ${e.message ?? 'Unknown error'}';
      }
      _showError(msg);
    } catch (e) {
      debugPrint('[LOGIN] Unexpected error: $e');
      // Check for specific known errors
      final errStr = e.toString().toLowerCase();
      String msg;
      if (errStr.contains('network') || errStr.contains('socketexception') || errStr.contains('connection refused')) {
        msg = '❌ Cannot connect to server.\n\nCheck your internet connection and try again.';
      } else if (errStr.contains('timeout')) {
        msg = '❌ Connection timed out.\n\nCheck your internet and try again.';
      } else if (errStr.contains('500') || errStr.contains('internal server')) {
        msg = '❌ Server error.\n\nPlease try again in a moment.';
      } else if (errStr.contains('sign_in_canceled') || errStr.contains('canceled')) {
        // User cancelled — silent
        setState(() { _loading = false; _status = ''; });
        return;
      } else {
        msg = '❌ Login failed:\n${e.toString()}';
      }
      _showError(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // App icon
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(
                      color: AppColors.accentStart.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )],
                  ),
                  child: const Icon(Icons.favorite_rounded, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const AppLogo(fontSize: 40, showTagline: true),

                const Spacer(flex: 2),

                // Step status message (visible while loading)
                if (_loading && _status.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _status,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Google Sign-In button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _googleSignIn,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide.none,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ).copyWith(
                      overlayColor: WidgetStateProperty.all(
                        AppColors.primary.withValues(alpha: 0.06),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.g_mobiledata, size: 26, color: Colors.red),
                              SizedBox(width: 10),
                              Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  'By continuing you agree to our Terms & Privacy Policy',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Debug button (only visible when not loading)
                if (!_loading)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DebugScreen()),
                    ),
                    child: const Text('Debug Info', style: TextStyle(fontSize: 10)),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
