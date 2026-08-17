import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/wallet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/coin_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  List<dynamic> _transactions = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Balance is updated via socket or displayed from cached provider value
    // Removed: walletProvider.fetchBalance() — reduces unnecessary API calls
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onWalletUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool refresh = true}) async {
    if (refresh) setState(() { _loading = true; _page = 1; _transactions = []; });
    try {
      final txResp = await api.get(ApiEndpoints.walletTransactions, params: {'page': '$_page', 'limit': '20'});
      // Backend returns: { success, data: [...transactions], meta: { hasNext, ... } }
      final rawData = txResp.data;
      final List<dynamic> list;
      final dynamic meta;

      if (rawData['data'] is List) {
        // data is directly an array
        list = rawData['data'] as List<dynamic>;
        meta = rawData['meta'];
      } else if (rawData['data'] is Map) {
        // data is an object with transactions array
        final dataMap = rawData['data'] as Map;
        list = (dataMap['transactions'] as List<dynamic>?) ?? (dataMap['data'] as List<dynamic>?) ?? [];
        meta = dataMap['meta'] ?? rawData['meta'];
      } else {
        list = [];
        meta = null;
      }

      setState(() {
        if (refresh) { _transactions = list; } else { _transactions.addAll(list); }
        _hasMore = (meta is Map) ? (meta['hasNext'] ?? false) : false;
        _loading = false;
      });
      // Balance will be updated via socket or displayed from cached value
      // Removed: walletProvider.fetchBalance(force: true) — reduces API calls
    } catch (e) {
      debugPrint('[WalletScreen] Error loading transactions: $e');
      setState(() => _loading = false);
    }
  }


  Future<void> _loadMore() async {
    if (!_hasMore) return;
    _page++;
    await _load(refresh: false);
  }

  Color _txColor(String type) {
    switch (type) {
      case 'RECHARGE': case 'BONUS': case 'PROMOTIONAL': return AppColors.success;
      case 'CALL_DEDUCTION': return AppColors.error;
      case 'REFUND': return AppColors.primary;
      default: return AppColors.textHint;
    }
  }

  IconData _txIcon(String type) {
    switch (type) {
      case 'RECHARGE': return Icons.add_circle_outline;
      case 'CALL_DEDUCTION': return Icons.phone_missed;
      case 'BONUS': return Icons.card_giftcard;
      case 'REFUND': return Icons.replay;
      default: return Icons.monetization_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ListenableBuilder(
              listenable: walletProvider,
              builder: (context, child) {
                return CoinBadge(balance: walletProvider.balance, onTap: () => context.push('/recharge'));
              },
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: CustomScrollView(slivers: [
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    AppCard(
                      child: Column(children: [
                        ShaderMask(
                          shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                          child: const Icon(Icons.monetization_on, size: 44, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        ListenableBuilder(
                          listenable: walletProvider,
                          builder: (context, child) {
                            return ShaderMask(
                              shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(walletProvider.balance.toInt().toString(), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            );
                          },
                        ),
                        const Text('Coins', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                        const SizedBox(height: 16),
                        SizedBox(width: double.infinity, child: ElevatedButton.icon(
                          onPressed: () async {
                            await context.push('/recharge');
                            // Refresh transactions after returning from recharge
                            // Balance will update via socket or optimistic update
                            _load();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Coins'),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    const Align(alignment: Alignment.centerLeft, child: Text('Transaction History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                  ]),
                )),
                if (_transactions.isEmpty)
                  const SliverFillRemaining(child: Center(child: Text('No transactions yet', style: TextStyle(color: AppColors.textSecondary))))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
                      if (i == _transactions.length) {
                        return _hasMore ? Padding(padding: const EdgeInsets.only(top: 8), child: TextButton(onPressed: _loadMore, child: const Text('Load more'))) : const SizedBox.shrink();
                      }
                      final t = _transactions[i] as Map<String, dynamic>;
                      final type = t['type'] as String;
                      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
                      final isPositive = amount > 0;
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(width: 42, height: 42,
                            decoration: BoxDecoration(color: _txColor(type).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                            child: Icon(_txIcon(type), color: _txColor(type), size: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(type.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                            if (t['description'] != null) Text(t['description'] as String, style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                            if (t['createdAt'] != null) Text(DateFormat('dd MMM, hh:mm a').format(DateTime.parse(t['createdAt'] as String)), style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                          ])),
                          Text('${isPositive ? '+' : ''}${amount.toStringAsFixed(0)}',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: isPositive ? AppColors.success : AppColors.error)),
                        ]),
                      );
                    }, childCount: _transactions.length + 1)),
                  ),
              ]),
            ),
    );
  }
}
