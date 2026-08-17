import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';

class ListenerCallsScreen extends StatefulWidget {
  const ListenerCallsScreen({super.key});
  @override
  State<ListenerCallsScreen> createState() => _ListenerCallsScreenState();
}

class _ListenerCallsScreenState extends State<ListenerCallsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _all = [], _audio = [], _video = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await api.get(ApiEndpoints.callHistory, params: {'limit': '50'});
      // Backend returns: { success: true, data: [...calls] } — data['data'] IS the array
      final list = (resp.data['data'] as List<dynamic>?) ?? [];
      setState(() {
        _all = list;
        _audio = list.where((c) => c['type'] == 'AUDIO').toList();
        _video = list.where((c) => c['type'] == 'VIDEO').toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      safeArea: false,
      appBar: AppBar(
        title: const Text('My Calls'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [Tab(text: 'All'), Tab(text: 'Audio'), Tab(text: 'Video')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(controller: _tabs, children: [_buildList(_all), _buildList(_audio), _buildList(_video)]),
    );
  }

  Widget _buildList(List<dynamic> calls) {
    if (calls.isEmpty) return const Center(child: Text('No calls found', style: TextStyle(color: AppColors.textSecondary)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: calls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final c = calls[i];
        final dur = c['durationSeconds'] != null ? '${(c['durationSeconds'] as int) ~/ 60}m ${(c['durationSeconds'] as int) % 60}s' : '--';
        final earning = c['earning']?['listenerAmount'];
        final type = c['type'] as String;
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(gradient: type == 'AUDIO' ? AppColors.accentGradient : const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3D7BFF)]), borderRadius: BorderRadius.circular(10)),
              child: Icon(type == 'AUDIO' ? Icons.mic : Icons.videocam, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['user']?['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text(DateFormat('dd MMM, hh:mm a').format(DateTime.parse(c['createdAt'] as String)), style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(dur, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
              if (earning != null) ...[const SizedBox(height: 3), Text('₹${double.parse(earning.toString()).toStringAsFixed(0)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13))],
              const SizedBox(height: 3),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: (c['status'] == 'COMPLETED' ? AppColors.success : AppColors.error).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Text(c['status'] as String, style: TextStyle(fontSize: 10, color: c['status'] == 'COMPLETED' ? AppColors.success : AppColors.error, fontWeight: FontWeight.w700))),
            ]),
          ]),
        );
      },
    );
  }
}
