import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';


class RecentsScreen extends StatefulWidget {
  const RecentsScreen({super.key});
  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen> {
  List<CallModel> _calls = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final resp = await api.get(ApiEndpoints.callHistory, params: {'limit': '10'});
      // Backend: { success: true, data: { data: [...calls], meta: {} } }
      final raw = resp.data['data'];
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List<dynamic>;
      }
      setState(() {
        _calls = list.map((j) => CallModel.fromJson(j as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Recents error: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Recents')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _calls.isEmpty
              ? const Center(child: Text('No recent calls', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _calls.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final c = _calls[i];
                    return AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        CircleAvatar(radius: 22, backgroundColor: AppColors.bgGradientBottom, backgroundImage: c.listenerPhoto != null ? NetworkImage(c.listenerPhoto!) : null, child: c.listenerPhoto == null ? Text(c.listenerName.isNotEmpty ? c.listenerName[0] : '?', style: const TextStyle(color: AppColors.accentStart, fontWeight: FontWeight.w700)) : null),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.listenerName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(c.status, style: TextStyle(fontSize: 11, color: c.status == 'COMPLETED' ? AppColors.success : AppColors.textHint)),
                        ])),
                        Icon(c.type == 'AUDIO' ? Icons.mic : Icons.videocam_outlined, color: c.type == 'AUDIO' ? AppColors.primary : AppColors.accentStart, size: 18),
                      ]),
                    );
                  },
                ),
    );
  }
}
