import 'package:flutter/material.dart';
import '../../../calls/presentation/screens/calls_tab_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../../core/theme/app_colors.dart';
import 'listener_dashboard_screen.dart';
import 'listener_earnings_screen.dart';

class ListenerMainScreen extends StatefulWidget {
  const ListenerMainScreen({super.key});
  @override
  State<ListenerMainScreen> createState() => _ListenerMainScreenState();
}

class _ListenerMainScreenState extends State<ListenerMainScreen> {
  int _index = 0;

  final _tabs = const [
    ListenerDashboardScreen(),
    CallsTabScreen(),
    ListenerEarningsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.call_outlined), activeIcon: Icon(Icons.call_rounded), label: 'Calls'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Earnings'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

