import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/models.dart';

class ListenerCallsScreen extends StatefulWidget {
  const ListenerCallsScreen({super.key});
  @override
  State<ListenerCallsScreen> createState() => _ListenerCallsScreenState();
}

class _ListenerCallsScreenState extends State<ListenerCallsScreen>
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
    try {
      final resp = await api.get(ApiEndpoints.callHistory, params: {'limit': '100'});
      final list = (resp.data['data'] as List<dynamic>?)
              ?.map((j) => CallModel.fromJson(j as Map<String, dynamic>))
              .toList() ??
          [];
      setState(() {
        _all   = list;
        _audio = list.where((c) => c.type == 'AUDIO').toList();
        _video = list.where((c) => c.type == 'VIDEO').toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = 'Failed to load call history'; });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF141428),
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Call History',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: const Color(0xFF141428),
                child: TabBar(
                  controller: _tabs,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  tabs: [
                    Tab(text: 'All (${_all.length})'),
                    Tab(text: 'Voice (${_audio.length})'),
                    Tab(text: 'Video (${_video.length})'),
                  ],
                ),
              ),
            ),
          ),
        ],
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
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ]),
      );

  Widget _buildList(List<CallModel> calls) {
    if (calls.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.call_outlined, color: Colors.white24, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No calls yet', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('Your call history will appear here', style: TextStyle(color: Colors.white24, fontSize: 13)),
        ]),
      );
    }

    // Group calls by date
    final grouped = <String, List<CallModel>>{};
    for (final call in calls) {
      final key = _dateKey(call.createdAt);
      grouped.putIfAbsent(key, () => []).add(call);
    }
    final dates = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: dates.length,
      itemBuilder: (ctx, di) {
        final date = dates[di];
        final dayCalls = grouped[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dateHeader(date),
            ...dayCalls.map((c) => _CallCard(call: c)),
          ],
        );
      },
    );
  }

  Widget _dateHeader(String label) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Row(children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: Colors.white10)),
        ]),
      );

  String _dateKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'TODAY';
    if (d == yesterday) return 'YESTERDAY';
    return DateFormat('dd MMM yyyy').format(dt).toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual call card — no overflow, no overlapping
// ─────────────────────────────────────────────────────────────────────────────
class _CallCard extends StatelessWidget {
  final CallModel call;
  const _CallCard({required this.call});

  @override
  Widget build(BuildContext context) {
    final isAudio  = call.type == 'AUDIO';
    final caller   = call.userName ?? 'Unknown User';
    final initials = _initials(caller);
    final dur      = _duration(call.durationSeconds);
    final timeStr  = DateFormat('hh:mm a').format(call.createdAt);
    final status   = call.status;
    final earning  = call.listenerEarning;
    final isCompleted = status == 'COMPLETED';
    final isMissed    = status == 'MISSED' || status == 'REJECTED';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withValues(alpha: 0.15)
              : isMissed
                  ? AppColors.error.withValues(alpha: 0.10)
                  : Colors.white10,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar ───────────────────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: isAudio
                        ? const LinearGradient(colors: [Color(0xFFFF2D9B), Color(0xFFFF6B35)])
                        : const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF3D7BFF)]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
                // Call type badge (bottom-right of avatar)
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D1A),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1A1A2E), width: 2),
                    ),
                    child: Icon(
                      isAudio ? Icons.mic_rounded : Icons.videocam_rounded,
                      color: isAudio ? const Color(0xFFFF2D9B) : const Color(0xFF6C63FF),
                      size: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 12),

            // ── Middle: name + time ──────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caller,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isMissed ? Icons.call_missed_rounded : Icons.call_received_rounded,
                        color: isMissed ? AppColors.error : AppColors.success,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      if (dur != null) ...[
                        const SizedBox(width: 6),
                        const Text('·', style: TextStyle(color: Colors.white24, fontSize: 12)),
                        const SizedBox(width: 6),
                        const Icon(Icons.access_time, color: Colors.white24, size: 11),
                        const SizedBox(width: 3),
                        Text(dur, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Right: status + earning ──────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (earning != null && earning > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.currency_rupee_rounded, color: Color(0xFF4CAF50), size: 12),
                      Text(
                        earning.toStringAsFixed(earning == earning.truncateToDouble() ? 0 : 1),
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  String? _duration(int? seconds) {
    if (seconds == null || seconds == 0) return null;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    if (s == 0) return '${m}m';
    return '${m}m ${s}s';
  }

  String _statusLabel(String status) => switch (status) {
        'COMPLETED' => 'COMPLETED',
        'MISSED'    => 'MISSED',
        'REJECTED'  => 'DECLINED',
        'CANCELLED' => 'CANCELLED',
        'RINGING'   => 'RINGING',
        _           => status,
      };

  Color _statusColor(String status) => switch (status) {
        'COMPLETED' => const Color(0xFF4CAF50),
        'MISSED'    => const Color(0xFFFF5252),
        'REJECTED'  => const Color(0xFFFF5252),
        'CANCELLED' => const Color(0xFFFF9800),
        _           => Colors.white38,
      };
}
