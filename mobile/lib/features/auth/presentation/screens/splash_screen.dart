import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/wallet_provider.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    final loggedIn = await SecureStorage.isLoggedIn();
    if (!loggedIn) {
      context.go('/auth/login');
      return;
    }

    // User is logged in - connect socket and check listener status
    await socketService.connect();

    // DO NOT fetch balance here - it will be fetched on login and updated via socket
    // Removed: walletProvider.fetchBalance() - causes unnecessary API call

    try {
      final resp = await api.get(ApiEndpoints.listenerMe);
      if (resp.statusCode == 200) {
        final listenerData = resp.data['data'];
        if (listenerData != null) {
          final status = listenerData['status'] as String? ?? '';
          debugPrint('🎧 Listener status: $status');

          // If APPROVED, always go to listener dashboard
          if (status == 'APPROVED' && mounted) {
            debugPrint('✅ Redirecting approved listener to dashboard');
            context.go('/listener/dashboard');
            return;
          }

          // If PENDING → show Under Review status screen
          if (status == 'PENDING' && mounted) {
            debugPrint('⏳ Listener is PENDING, showing under-review screen');
            context.go('/listener/under-review');
            return;
          }

          // If REJECTED → show Under Review screen with rejection state
          if (status == 'REJECTED' && mounted) {
            debugPrint('❌ Listener is REJECTED, showing under-review screen');
            context.go('/listener/under-review');
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Listener check failed: $e');
      // Not a listener or API error → go to home as regular user
    }

    if (!mounted) return;
    context.go('/home');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [BoxShadow(color: AppColors.accentStart.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 10))],
                    ),
                    child: const Icon(Icons.favorite_rounded, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const AppLogo(fontSize: 42, showTagline: true),
                  const SizedBox(height: 40),
                  SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
