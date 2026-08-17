import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../wallet/presentation/screens/wallet_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import 'home_screen.dart';
import 'recents_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  final _tabs = const [
    HomeScreen(),
    RecentsScreen(),
    WalletScreen(),
    ProfileScreen(),
  ];

  static const _navItems = [
    _NavItem(icon: Icons.home_outlined,    activeIcon: Icons.home_rounded,       label: 'Home'),
    _NavItem(icon: Icons.history_outlined, activeIcon: Icons.history_rounded,     label: 'Recents'),
    _NavItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _checkListenerStatus();
  }

  Future<void> _checkListenerStatus() async {
    // If user is an approved listener, redirect them to listener dashboard
    try {
      final resp = await api.get(ApiEndpoints.listenerMe);
      if (resp.statusCode == 200) {
        final listenerData = resp.data['data'];
        if (listenerData != null) {
          final status = listenerData['status'] as String? ?? '';
          if (status == 'APPROVED' && mounted) {
            debugPrint('✅ Approved listener detected in MainScreen, redirecting to dashboard');
            context.go('/listener/dashboard');
          }
        }
      }
    } catch (_) {
      // Not a listener - stay on user home
    }
  }

  @override
  Widget build(BuildContext context) {
    // Make system nav bar transparent so it blends with the app background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: IndexedStack(index: _index, children: _tabs),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      // Add bottom inset so the pill nav bar floats above the system nav bar
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 12),
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9B59B6).withValues(alpha: 0.12),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, -2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navItems.length, (i) {
          final item = _navItems[i];
          final selected = _index == i;
          return GestureDetector(
            onTap: () => setState(() => _index = i),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Icon — gradient when active, gray when not
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: selected
                            ? ShaderMask(
                                key: const ValueKey('active'),
                                shaderCallback: (bounds) =>
                                    AppColors.pinkPurpleGradient.createShader(bounds),
                                child: Icon(item.activeIcon, size: 24, color: Colors.white),
                              )
                            : Icon(
                                key: const ValueKey('inactive'),
                                item.icon,
                                size: 24,
                                color: AppColors.textHint,
                              ),
                      ),
                      // Notification badge
                      if (item.badge != null && item.badge! > 0)
                        Positioned(
                          top: -4,
                          right: -6,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppColors.badgeRed,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${item.badge}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.pink : AppColors.textHint,
                    ),
                  ),
                  // Active indicator dot
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: selected ? 16 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: selected ? AppColors.pinkPurpleGradient : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
      ), // close outer Container
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badge;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });
}
