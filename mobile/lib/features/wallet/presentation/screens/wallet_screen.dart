import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/wallet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/milan_coin.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _transactions = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  int _filterIndex = 0; // 0=All, 1=Credited, 2=Debited

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = true}) async {
    if (refresh) {
      setState(() { _loading = true; _page = 1; _transactions = []; });
    }
    try {
      final txResp = await api.get(ApiEndpoints.walletTransactions,
          params: {'page': '$_page', 'limit': '30'});
      final rawData = txResp.data;
      final List<dynamic> list;
      final dynamic meta;

      if (rawData['data'] is List) {
        list = rawData['data'] as List<dynamic>;
        meta = rawData['meta'];
      } else if (rawData['data'] is Map) {
        final dataMap = rawData['data'] as Map;
        list = (dataMap['transactions'] as List<dynamic>?) ??
            (dataMap['data'] as List<dynamic>?) ?? [];
        meta = dataMap['meta'] ?? rawData['meta'];
      } else {
        list = [];
        meta = null;
      }

      if (mounted) {
        setState(() {
          if (refresh) {
            _transactions = list;
          } else {
            _transactions.addAll(list);
          }
          _hasMore = (meta is Map) ? (meta['hasNext'] ?? false) : false;
          _loading = false;
        });
        if (refresh) _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      debugPrint('[WalletScreen] Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    _page++;
    try {
      await _load(refresh: false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<dynamic> get _filtered {
    if (_filterIndex == 1) {
      return _transactions.where((t) {
        final amt = (t['amount'] as num?)?.toDouble() ?? 0;
        return amt > 0;
      }).toList();
    }
    if (_filterIndex == 2) {
      return _transactions.where((t) {
        final amt = (t['amount'] as num?)?.toDouble() ?? 0;
        return amt < 0;
      }).toList();
    }
    return _transactions;
  }

  double get _totalSpent => _transactions.fold(0.0, (sum, t) {
        final amt = (t['amount'] as num?)?.toDouble() ?? 0;
        return sum + (amt < 0 ? amt.abs() : 0);
      });

  double get _totalAdded => _transactions.fold(0.0, (sum, t) {
        final amt = (t['amount'] as num?)?.toDouble() ?? 0;
        return sum + (amt > 0 ? amt : 0);
      });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: CustomScrollView(slivers: [
                        SliverToBoxAdapter(child: _buildBalanceCard()),
                        SliverToBoxAdapter(child: _buildStatsRow()),
                        SliverToBoxAdapter(child: _buildFilterRow()),
                        _buildTransactionList(),
                        if (_hasMore)
                          SliverToBoxAdapter(child: _buildLoadMoreBtn()),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: AppColors.pinkPurpleGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: AppColors.pink.withValues(alpha: 0.3),
                  blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: const Center(child: MilanCoin(size: 24, glow: false)),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('My Wallet',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Text('Manage your coins',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textHint)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: _loading ? null : _load,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: _loading
                ? const Padding(padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded,
                    color: AppColors.textSecondary, size: 20),
          ),
        ),
      ]),
    );
  }

  // ── Balance Card ───────────────────────────────────────────────────────────

  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.bannerGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: AppColors.pink.withValues(alpha: 0.28),
                blurRadius: 24, offset: const Offset(0, 8)),
            BoxShadow(color: AppColors.purple.withValues(alpha: 0.15),
                blurRadius: 40, offset: const Offset(0, 4)),
          ],
        ),
        child: Stack(children: [
          // Background decoration circles
          Positioned(top: -20, right: -20,
            child: Container(width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05)))),
          Positioned(bottom: -30, left: -10,
            child: Container(width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04)))),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              // Coin + Balance
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const MilanCoin(size: 52, glow: true),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Your Balance',
                      style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13, fontWeight: FontWeight.w400)),
                  ListenableBuilder(
                    listenable: walletProvider,
                    builder: (_, __) => Text(
                      walletProvider.balance.toInt().toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  Text('Coins',
                      style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              ]),

              const SizedBox(height: 20),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 16),

              // Add Coins button
              GestureDetector(
                onTap: () async {
                  await context.push('/recharge');
                  _load();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(
                        gradient: AppColors.pinkPurpleGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text('Add Coins',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 15,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(width: 6),
                    const MilanCoin(size: 18, glow: false),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(children: [
        Expanded(child: _StatChip(
          label: 'Total Added',
          value: _totalAdded.toInt(),
          icon: Icons.arrow_downward_rounded,
          color: AppColors.success,
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatChip(
          label: 'Total Spent',
          value: _totalSpent.toInt(),
          icon: Icons.arrow_upward_rounded,
          color: AppColors.error,
        )),
      ]),
    );
  }

  // ── Filter Row ─────────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    final labels = ['All', 'Credited', 'Debited'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Transaction History',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(children: List.generate(3, (i) {
          final active = _filterIndex == i;
          return Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _filterIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: active ? AppColors.pinkPurpleGradient : null,
                  color: active ? null : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: active
                          ? AppColors.pink.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(labels[i],
                    style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.textSecondary,
                    )),
              ),
            ),
          );
        })),
      ]),
    );
  }

  // ── Transaction List ───────────────────────────────────────────────────────

  Widget _buildTransactionList() {
    final list = _filtered;
    if (list.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(child: MilanCoin(size: 36, glow: false)),
            ),
            const SizedBox(height: 14),
            Text('No transactions yet',
                style: GoogleFonts.poppins(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Your coin history will appear here',
                style: GoogleFonts.poppins(
                    color: AppColors.textHint, fontSize: 12)),
          ]),
        )),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final t = list[i] as Map<String, dynamic>;
            return _TxItem(tx: t);
          },
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _buildLoadMoreBtn() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: _loadingMore
            ? const SizedBox(height: 24, width: 24,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
            : GestureDetector(
                onTap: _loadMore,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8)],
                  ),
                  child: Text('Load more',
                      style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
      ),
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10, color: AppColors.textHint,
                    fontWeight: FontWeight.w400)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const MilanCoin(size: 13, glow: false),
              const SizedBox(width: 4),
              Text('$value',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ]),
          ],
        )),
      ]),
    );
  }
}

// ── Transaction Item ──────────────────────────────────────────────────────────

class _TxItem extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TxItem({required this.tx});

  String get _type => (tx['type'] as String?) ?? 'UNKNOWN';
  double get _amount => (tx['amount'] as num?)?.toDouble() ?? 0;
  bool get _isPositive => _amount > 0;

  Color get _color => _isPositive ? AppColors.success : AppColors.error;

  String get _label {
    switch (_type) {
      case 'RECHARGE':      return 'Coins Added';
      case 'CALL_DEDUCTION': return 'Call Deduction';
      case 'BONUS':         return 'Bonus Coins';
      case 'REFUND':        return 'Refund';
      case 'PROMOTIONAL':   return 'Promotional';
      default:              return _type.replaceAll('_', ' ');
    }
  }

  IconData get _icon {
    switch (_type) {
      case 'RECHARGE':       return Icons.add_circle_rounded;
      case 'CALL_DEDUCTION': return Icons.phone_rounded;
      case 'BONUS':          return Icons.card_giftcard_rounded;
      case 'REFUND':         return Icons.reply_rounded;
      case 'PROMOTIONAL':    return Icons.local_offer_rounded;
      default:               return Icons.swap_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        // Icon box
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(_icon, color: _color, size: 20),
        ),
        const SizedBox(width: 12),

        // Label + time
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_label,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            if (tx['description'] != null && (tx['description'] as String).isNotEmpty)
              Text(tx['description'] as String,
                  style: GoogleFonts.poppins(
                      color: AppColors.textHint, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            if (tx['createdAt'] != null)
              Text(
                DateFormat('dd MMM yyyy, hh:mm a')
                    .format(DateTime.parse(tx['createdAt'] as String)),
                style: GoogleFonts.poppins(
                    color: AppColors.textHint, fontSize: 10),
              ),
          ],
        )),

        const SizedBox(width: 10),

        // Amount with MilanCoin
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(
              _isPositive ? '+' : '-',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800, fontSize: 16,
                  color: _color),
            ),
            const SizedBox(width: 3),
            const MilanCoin(size: 16, glow: false),
            const SizedBox(width: 4),
            Text(
              _amount.abs().toStringAsFixed(0),
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800, fontSize: 16,
                  color: _color),
            ),
          ]),
          Container(
            margin: const EdgeInsets.only(top: 3),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _isPositive ? 'Credited' : 'Debited',
              style: GoogleFonts.poppins(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: _color),
            ),
          ),
        ]),
      ]),
    );
  }
}
