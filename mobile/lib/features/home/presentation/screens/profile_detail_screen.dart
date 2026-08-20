import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';


class ProfileDetailScreen extends StatefulWidget {
  final String listenerId;
  const ProfileDetailScreen({super.key, required this.listenerId});
  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  ListenerModel? _listener;
  bool _loading = true;
  late final Function(dynamic) _onListenerStatus;

  @override
  void initState() {
    super.initState();
    _onListenerStatus = _handleListenerStatus;
    socketService.addListener('listener:status', _onListenerStatus);
    _load();
  }

  @override
  void dispose() {
    socketService.removeListener('listener:status', _onListenerStatus);
    super.dispose();
  }

  /// Update status in real-time when this specific listener goes online/offline.
  void _handleListenerStatus(dynamic data) {
    if (data is! Map) return;
    final listenerId = data['listenerId'] as String?;
    final status     = data['status']     as String?;
    if (listenerId != widget.listenerId || status == null) return;
    if (_listener == null || !mounted) return;
    setState(() => _listener = _listener!.copyWith(onlineStatus: status));
    debugPrint('[PROFILE_DETAIL] listener:status → $status');
  }

  Future<void> _load() async {
    try {
      final resp = await api.get(ApiEndpoints.listenerDetail(widget.listenerId));
      setState(() { _listener = ListenerModel.fromJson(resp.data['data']); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Container(decoration: const BoxDecoration(gradient: AppColors.backgroundGradient), child: const Scaffold(backgroundColor: Colors.transparent, body: Center(child: CircularProgressIndicator(color: AppColors.primary))));
    if (_listener == null) return GradientScaffold(appBar: AppBar(title: const Text('Not Found')), body: const Center(child: Text('Listener not found')));
    final l = _listener!;
    return GradientScaffold(
      safeArea: false,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: l.photoUrl != null
                  ? Image.network(l.photoUrl!, fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(gradient: AppColors.accentGradient),
                      child: Center(child: Text(l.displayName[0], style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w700, color: Colors.white))),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${l.displayName}${l.age != null ? ', ${l.age}' : ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                    const Icon(Icons.verified, color: AppColors.primary, size: 20),
                  ]),
                  if (l.city != null) ...[const SizedBox(height: 4), Row(children: [const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textHint), const SizedBox(width: 3), Text(l.city!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))])],
                  const SizedBox(height: 12),
                  Row(children: [
                    _stat(Icons.star_rounded, l.rating.toStringAsFixed(1), 'Rating', AppColors.gold),
                    const SizedBox(width: 20),
                    _stat(Icons.call_outlined, l.totalCalls.toString(), 'Calls', AppColors.primary),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: (l.isOnline ? AppColors.online : l.isBusy ? AppColors.busy : AppColors.offline).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: l.isOnline ? AppColors.online : l.isBusy ? AppColors.busy : AppColors.offline, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(l.isOnline ? 'Online' : l.isBusy ? 'Busy' : 'Offline', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: l.isOnline ? AppColors.online : l.isBusy ? AppColors.busy : AppColors.offline)),
                      ]),
                    ),
                  ]),
                  if (l.bio != null && l.bio!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('About', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      l.bio!,
                      style: const TextStyle(color: AppColors.textSecondary, height: 1.6, fontSize: 13),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ])),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _callButton(context, isAudio: true, enabled: l.isOnline && l.isAudioEnabled, listenerId: l.id, listenerName: l.displayName, photo: l.photoUrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _callButton(context, isAudio: false, enabled: l.isOnline && l.isVideoEnabled, listenerId: l.id, listenerName: l.displayName, photo: l.photoUrl)),
                ]),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
      ]),
    ]);
  }

  Widget _callButton(BuildContext context, {required bool isAudio, required bool enabled, required String listenerId, required String listenerName, String? photo}) {
    return ElevatedButton.icon(
      onPressed: enabled ? () => context.push(isAudio ? '/call/audio' : '/call/video', extra: {'listenerId': listenerId, 'listenerName': listenerName, 'listenerPhoto': photo}) : null,
      icon: Icon(isAudio ? Icons.mic : Icons.videocam, size: 18),
      label: Text(isAudio ? 'Audio · $audioRateDefault/min' : 'Video · $videoRateDefault/min'),
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? (isAudio ? AppColors.primary : AppColors.accentStart) : AppColors.surfaceLight,
        foregroundColor: enabled ? Colors.white : AppColors.textHint,
      ),
    );
  }
}
