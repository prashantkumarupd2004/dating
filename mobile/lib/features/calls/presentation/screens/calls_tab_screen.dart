import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/models.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';

class CallsTabScreen extends StatefulWidget {
  const CallsTabScreen({super.key});
  @override
  State<CallsTabScreen> createState() => _CallsTabScreenState();
}

class _CallsTabScreenState extends State<CallsTabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<CallModel> _all = [], _audio = [], _video = [];
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
      // Backend: { success: true, data: { data: [...calls], meta: {} } }
      final raw = resp.data['data'];
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List<dynamic>;
      }
      final calls = list.map((j) => CallModel.fromJson(j as Map<String, dynamic>)).toList();
      setState(() {
        _all = calls;
        _audio = calls.where((c) => c.type == 'AUDIO').toList();
        _video = calls.where((c) => c.type == 'VIDEO').toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Call history error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      safeArea: false,
      appBar: AppBar(
        title: const Text('Call History'),
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

  Widget _buildList(List<CallModel> calls) {
    if (calls.isEmpty) return const Center(child: Text('No calls found', style: TextStyle(color: AppColors.textSecondary)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: calls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final c = calls[i];
        final durSecs = c.durationSeconds ?? 0;
        final dur = durSecs > 0 ? '${durSecs ~/ 60}m ${durSecs % 60}s' : '--';
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(radius: 24, backgroundColor: AppColors.bgGradientBottom, backgroundImage: c.listenerPhoto != null ? NetworkImage(c.listenerPhoto!) : null, child: c.listenerPhoto == null ? Text(c.listenerName.isNotEmpty ? c.listenerName[0] : '?', style: const TextStyle(color: AppColors.accentStart, fontWeight: FontWeight.w700)) : null),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.listenerName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text(DateFormat('dd MMM, hh:mm a').format(c.createdAt), style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Icon(c.type == 'AUDIO' ? Icons.mic : Icons.videocam, size: 13, color: c.type == 'AUDIO' ? AppColors.primary : AppColors.accentStart),
                const SizedBox(width: 4),
                Text(dur, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _statusColor(c.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(c.status, style: TextStyle(color: _statusColor(c.status), fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        );
      },
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'COMPLETED': return AppColors.success;
      case 'MISSED': return AppColors.busy;
      case 'REJECTED': case 'FAILED': return AppColors.error;
      default: return AppColors.textHint;
    }
  }
}
