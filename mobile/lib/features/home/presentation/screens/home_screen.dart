import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/wallet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/listener_card.dart';
import '../../../../shared/widgets/coin_badge.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/milan_coin.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ListenerModel> _listeners = [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';

  static const _categories = ['All', '⭐ Star', '♡ Relationship', '💍 Marriage', '🛡 Confidence', 'Friends'];

  @override
  void initState() {
    super.initState();
    _load();
    // Balance is fetched automatically via socket updates or manual refresh
    // Removed: walletProvider.fetchBalance() — reduces unnecessary API calls
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onWalletUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await api.get(ApiEndpoints.listeners, params: {'limit': '30'});
      final raw = resp.data['data'];
      final listenersData =
          (raw is List) ? raw as List<dynamic> : (raw is Map ? (raw.values.first as List<dynamic>?) ?? [] : []);
      _listeners = listenersData.map((j) => ListenerModel.fromJson(j)).toList();
      if (mounted) setState(() { _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load listeners. Please try again.'; _loading = false; });
    }
  }

  void _randomCall() {
    final online = _listeners.where((l) => l.isOnline).toList();
    if (online.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No listeners online right now'), backgroundColor: AppColors.error),
      );
      return;
    }
    final pick = online[Random().nextInt(online.length)];
    // Start audio call by default (can be enhanced to show audio/video choice dialog)
    context.push('/call/audio', extra: {
      'listenerId': pick.id,
      'listenerName': pick.displayName,
      'listenerPhoto': pick.photoUrl,
      'listenerCity': pick.city,
      'listenerAge': pick.age,
    });
  }

  List<ListenerModel> get _filtered {
    if (_filter == '⭐ Star') return _listeners.where((l) => l.isFeatured || l.rating >= 4.8).toList();
    if (_filter == '♡ Relationship') return _listeners.where((l) => l.expertise?.toLowerCase().contains('relation') ?? false).toList();
    if (_filter == '💍 Marriage') return _listeners.where((l) => l.expertise?.toLowerCase().contains('marriage') ?? false).toList();
    if (_filter == '🛡 Confidence') return _listeners.where((l) => l.expertise?.toLowerCase().contains('confidence') ?? false).toList();
    if (_filter == 'Friends') return _listeners.where((l) => l.expertise?.toLowerCase().contains('friend') ?? false).toList();
    return _listeners;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await _load();
            await walletProvider.fetchBalance(force: true);
          },
          color: AppColors.pink,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildBanner()),
              SliverToBoxAdapter(child: _buildSectionHeader()),
              SliverToBoxAdapter(child: _buildFilterChips()),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.pink)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                          const SizedBox(height: 16),
                          Text(_error!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_filtered.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('No listeners available right now',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                SliverPadding(
                  // Extra bottom padding so last card clears the floating nav bar
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => ListenerCard(listener: _filtered[i], onRefresh: _load),
                      childCount: _filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Expanded(child: AppLogo()),
          ListenableBuilder(
            listenable: walletProvider,
            builder: (context, child) {
              return CoinBadge(balance: walletProvider.balance, onTap: () => context.push('/recharge'));
            },
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push('/settings/account'),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.pinkPurpleGradient,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const ClipOval(child: Icon(Icons.person_rounded, size: 24, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      height: 90,
      decoration: BoxDecoration(
        gradient: AppColors.bannerGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppColors.pink.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _WavePainter())),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Connect & Make Friends',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('@ ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFFFF176))),
                            const MilanCoin(size: 14, glow: false),
                            Text(' 10/min only!',
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFFFF176))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _randomCall,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB03A8E),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shuffle_rounded, size: 15, color: Colors.white),
                          const SizedBox(width: 5),
                          Text('Random Call', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Text('Listeners ', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const Spacer(),
          Text('${_listeners.where((l) => l.isOnline).length} online',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.online, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = _filter == cat;
          return GestureDetector(
            onTap: () => setState(() => _filter = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: selected ? AppColors.pinkPurpleGradient : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: selected ? null : Border.all(color: AppColors.pink.withValues(alpha: 0.25), width: 1),
                boxShadow: selected
                    ? [BoxShadow(color: AppColors.pink.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 3))]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Text(cat, style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.textSecondary,
              )),
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final path1 = Path();
    path1.moveTo(0, size.height * 0.6);
    path1.quadraticBezierTo(size.width * 0.25, size.height * 0.4, size.width * 0.5, size.height * 0.55);
    path1.quadraticBezierTo(size.width * 0.75, size.height * 0.7, size.width, size.height * 0.5);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    canvas.drawPath(path1, paint);

    final paint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    final path2 = Path();
    path2.moveTo(0, size.height * 0.75);
    path2.quadraticBezierTo(size.width * 0.3, size.height * 0.55, size.width * 0.6, size.height * 0.7);
    path2.quadraticBezierTo(size.width * 0.8, size.height * 0.8, size.width, size.height * 0.65);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(_) => false;
}
