import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';

// Safe number parser — handles Prisma Decimal (comes as String in JSON)
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

class ListenerEarningsScreen extends StatefulWidget {
  const ListenerEarningsScreen({super.key});
  @override
  State<ListenerEarningsScreen> createState() => _ListenerEarningsScreenState();
}

class _ListenerEarningsScreenState extends State<ListenerEarningsScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic> _history = [];
  bool _loading = true;
  DateTime? _lastRefresh; // Track last refresh time

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    // Prevent rapid refresh - only allow refresh every 30 seconds
    if (_lastRefresh != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefresh!);
      if (timeSinceLastRefresh.inSeconds < 30) {
        debugPrint('⏸️ [Earnings] Skipping refresh - last refresh was ${timeSinceLastRefresh.inSeconds}s ago');
        return;
      }
    }

    // Prevent concurrent requests
    if (_loading) {
      debugPrint('⏸️ [Earnings] Already loading, skipping...');
      return;
    }

    setState(() => _loading = true);
    _lastRefresh = DateTime.now();

    try {
      final results = await Future.wait([
        api.get(ApiEndpoints.earningsSummary),
        api.get(ApiEndpoints.earningsHistory, params: {'limit': '30'}),
      ]);

      // Summary — flat keys from updated backend
      final summaryRaw = results[0].data['data'];

      // Earnings history — paginated: { data: [...], meta: {} }
      final historyRaw = results[1].data['data'];
      List<dynamic> historyList = [];
      if (historyRaw is List) {
        historyList = historyRaw;
      } else if (historyRaw is Map && historyRaw['data'] is List) {
        historyList = historyRaw['data'] as List<dynamic>;
      }

      setState(() {
        _summary = summaryRaw as Map<String, dynamic>?;
        _history = historyList;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Earnings load error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Support both old keys (today/week/month/wallet) and new flat keys
    final todayEarnings = _toDouble(_summary?['todayEarnings'] ?? _summary?['today']);
    final weekEarnings  = _toDouble(_summary?['weekEarnings']  ?? _summary?['week']);
    final monthEarnings = _toDouble(_summary?['monthEarnings'] ?? _summary?['month']);
    final available = _toDouble(
      _summary?['availableBalance'] ?? (_summary?['wallet'] as Map?)?['availableBalance']
    );
    final totalEarnings = _toDouble(
      _summary?['totalEarnings'] ?? (_summary?['wallet'] as Map?)?['totalEarned']
    );

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [TextButton(onPressed: () => context.push('/listener/payout'), child: const Text('Payout', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _card('Today', '₹${todayEarnings.toStringAsFixed(0)}', AppColors.primary),
                    const SizedBox(width: 12),
                    _card('This Week', '₹${weekEarnings.toStringAsFixed(0)}', AppColors.accentStart),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _card('This Month', '₹${monthEarnings.toStringAsFixed(0)}', AppColors.success),
                    const SizedBox(width: 12),
                    _card('Available', '₹${available.toStringAsFixed(0)}', AppColors.gold),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _card('Total Earned', '₹${totalEarnings.toStringAsFixed(0)}', AppColors.accentStart),
                    const SizedBox(width: 12),
                    _card('Today Calls', '${_toInt(_summary?['todayCalls'])}', AppColors.purple),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: () => context.push('/listener/payout'),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    label: const Text('Request Payout'),
                  )),
                  const SizedBox(height: 24),
                  const Text('Earning History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  if (_history.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No earnings yet', style: TextStyle(color: AppColors.textSecondary))))
                  else
                    ..._history.map((e) => _earningTile(e as Map<String, dynamic>)),
                ]),
              ),
            ),
    );
  }

  Widget _card(String label, String value, Color color) => Expanded(
    child: AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      ]),
    ),
  );

  Widget _earningTile(Map<String, dynamic> e) {
    final call = e['call'] as Map<String, dynamic>?;
    final type = call?['type'] as String? ?? 'AUDIO';
    final dur = _toInt(call?['durationSeconds']);
    // Prisma Decimal comes as String in JSON — use safe parser
    final amount = _toDouble(e['listenerAmount']);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: type == 'AUDIO' ? AppColors.accentGradient : const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3D7BFF)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(type == 'AUDIO' ? Icons.mic : Icons.videocam, color: Colors.white, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type == 'AUDIO' ? 'Audio Call' : 'Video Call', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
          Text(dur > 0 ? '${dur ~/ 60}m ${dur % 60}s' : '--', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 16)),
          if (e['createdAt'] != null) Text(DateFormat('dd MMM').format(DateTime.parse(e['createdAt'] as String)), style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
        ]),
      ]),
    );
  }
}
