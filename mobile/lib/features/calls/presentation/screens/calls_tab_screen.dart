import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/models.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';

class CallsTabScreen extends StatefulWidget {
  const CallsTabScreen({super.key});
  @override
  State<CallsTabScreen> createState() => _CallsTabScreenState();
}

class _CallsTabScreenState extends State<CallsTabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<CallModel> _all = [], _audio = [], _video = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await api.get(ApiEndpoints.callHistory, params: {'limit': '50'});
      final raw = resp.data['data'];
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List<dynamic>;
      }
      final calls = list
          .map((j) => CallModel.fromJson(j as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _all   = calls;
          _audio = calls.where((c) => c.type == 'AUDIO').toList();
          _video = calls.where((c) => c.type == 'VIDEO').toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Call history error: $e');
      if (mounted) setState(() { _loading = false; _error = 'Failed to load history'; });
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
        title: Text('Call History', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
          tabs: [
            Tab(text: 'All (${_all.length})'),
            Tab(text: 'Voice (${_audio.length})'),
            Tab(text: 'Video (${_video.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildList(_all),
                    _buildList(_audio),
                    _buildList(_video),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: AppColors.textHint, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
        ),
      ]),
    );
  }

  Widget _buildList(List<CallModel> calls) {
    if (calls.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.call_outlined, color: AppColors.textHint.withValues(alpha: 0.4), size: 56),
          const SizedBox(height: 12),
          Text('No calls yet',
              style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Your call history will appear here',
              style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 12)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: calls.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _CallHistoryItem(call: calls[i]),
      ),
    );
  }
}

// ── Single Call History Item ──────────────────────────────────────────────────

class _CallHistoryItem extends StatelessWidget {
  final CallModel call;
  const _CallHistoryItem({required this.call});

  bool get _isVideo => call.type == 'VIDEO';

  Color get _typeColor => _isVideo ? AppColors.blue : AppColors.primary;

  Color _statusColor(String s) {
    switch (s) {
      case 'COMPLETED': return AppColors.online;
      case 'MISSED':    return AppColors.busy;
      case 'REJECTED':
      case 'FAILED':
      case 'CANCELLED': return AppColors.error;
      default:          return AppColors.textHint;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'COMPLETED': return 'Completed';
      case 'MISSED':    return 'Missed';
      case 'REJECTED':  return 'Declined';
      case 'FAILED':    return 'Failed';
      case 'CANCELLED': return 'Cancelled';
      default:          return s;
    }
  }

  String get _duration {
    final secs = call.durationSeconds ?? 0;
    if (secs <= 0) return '--';
    if (secs < 60) return '${secs}s';
    final m = secs ~/ 60;
    final s = secs % 60;
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(call.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B59B6).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // ── Avatar ──────────────────────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: _typeColor.withValues(alpha: 0.12),
              backgroundImage: call.listenerPhoto != null
                  ? NetworkImage(call.listenerPhoto!)
                  : null,
              onBackgroundImageError: call.listenerPhoto != null
                  ? (_, __) {} : null,
              child: call.listenerPhoto == null
                  ? Text(
                      call.listenerName.isNotEmpty ? call.listenerName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: _typeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            // Call type badge (bottom-right of avatar)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _typeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  _isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),

        // ── Middle: name + type + time ───────────────────────────────────
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              call.listenerName,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isVideo ? 'Video Call' : 'Voice Call',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _typeColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.access_time_rounded, size: 11, color: AppColors.textHint),
              const SizedBox(width: 3),
              Text(
                DateFormat('dd MMM · hh:mm a').format(call.createdAt),
                style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textHint),
              ),
            ]),
          ]),
        ),

        // ── Right: duration + coins + status ─────────────────────────────
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          // Duration
          if (call.durationSeconds != null && call.durationSeconds! > 0)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.timer_outlined, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 3),
              Text(
                _duration,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ]),
          // Coins
          if (call.coinsDeducted != null && call.coinsDeducted! > 0) ...[
            const SizedBox(height: 3),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.monetization_on_rounded, size: 12, color: AppColors.gold),
              const SizedBox(width: 3),
              Text(
                '${call.coinsDeducted!.toStringAsFixed(0)} coins',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            ]),
          ],
          const SizedBox(height: 5),
          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel(call.status),
              style: GoogleFonts.poppins(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
