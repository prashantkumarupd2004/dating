import 'package:flutter/material.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/locale_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'listener_account_screen.dart';
import 'listener_calls_screen.dart';
import 'listener_dashboard_screen.dart';
import 'listener_earnings_screen.dart';

class ListenerMainScreen extends StatefulWidget {
  const ListenerMainScreen({super.key});
  @override
  State<ListenerMainScreen> createState() => _ListenerMainScreenState();
}

class _ListenerMainScreenState extends State<ListenerMainScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    localeService.locale.addListener(_onLocaleChange);
  }

  @override
  void dispose() {
    localeService.locale.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  final _tabs = const [
    ListenerDashboardScreen(),
    ListenerCallsScreen(),
    ListenerEarningsScreen(),
    ListenerAccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.current;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: IndexedStack(index: _index, children: _tabs),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius: 12, offset: Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textHint,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.dashboard_outlined), activeIcon: const Icon(Icons.dashboard_rounded), label: l.dashboard),
            BottomNavigationBarItem(icon: const Icon(Icons.call_outlined), activeIcon: const Icon(Icons.call_rounded), label: l.calls),
            BottomNavigationBarItem(icon: const Icon(Icons.account_balance_wallet_outlined), activeIcon: const Icon(Icons.account_balance_wallet_rounded), label: l.earnings),
            BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person_rounded), label: l.account),
          ],
        ),
      ),
    );
  }
}
