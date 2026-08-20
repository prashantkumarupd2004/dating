import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/models.dart';

class RecentsScreen extends StatefulWidget {
  const RecentsScreen({super.key});
  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen>
    with SingleTickerProviderStateMixin {
  List<CallModel> _all = [];
  bool _loading = true;
  String? _error;
  int _filterIndex = 0; // 0=All, 1=Voice, 2=Video

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
      if (mounted) {
        setState(() {
          _all = list.map((j) => CallModel.fromJson(j as Map<String, dynamic>)).toList();
          _loading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (e) {
      debugPrint('Recents error: $e');
      if (mounted) setState(() { _loading = false; _error = 'Failed to load history'; });
    }
  }

  List<CallModel> get _filtered {
    if (_filterIndex == 1) return _all.where((c) => c.type == 'AUDIO').toList();
    if (_filterIndex == 2) return _all.where((c) => c.type == 'VIDEO').toList();
    return _all;
  }

  /// Group calls by date section: Today / Yesterday / DD MMM YYYY
  Map<String, List<CallModel>> _group(List<CallModel> calls) {
    final now = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final groups = <String, List<CallModel>>{};
    for (final c in calls) {
      final d = DateTime(c.createdAt.year, c.createdAt.month, c.createdAt.day);
      String key;
      if (d == today) {
        key = 'Today';
      } else if (d == yesterday) {
        key = 'Yesterday';
      } else {
        key = DateFormat('dd MMM yyyy').format(c.createdAt);
      }
      groups.putIfAbsent(key, () => []).add(c);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        // Gradient icon
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
          child: const Icon(Icons.history_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recent Calls',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          Text('${_all.length} calls total',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppColors.textHint,
                  fontWeight: FontWeight.w400)),
        ]),
        const Spacer(),
        // Refresh button
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
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded,
                    color: AppColors.textSecondary, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _buildFilterChips() {
    final audioCount = _all.where((c) => c.type == 'AUDIO').length;
    final videoCount = _all.where((c) => c.type == 'VIDEO').length;
    final labels = [
      'All (${_all.length})',
      'Voice ($audioCount)',
      'Video ($videoCount)',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(children: List.generate(3, (i) {
        final active = _filterIndex == i;
        return Padding(
          padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
          child: GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: active ? AppColors.pinkPurpleGradient : null,
                color: active ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: active
                        ? AppColors.pink.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                labels[i],
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      })),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded,
            color: AppColors.textHint, size: 52),
        const SizedBox(height: 12),
        Text(_error!,
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppColors.pinkPurpleGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Retry',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ]));
    }

    final filtered = _filtered;
    if (filtered.isEmpty) return _buildEmpty();

    final groups = _group(filtered);

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
          itemCount: groups.entries.fold<int>(0, (sum, e) => sum + 1 + e.value.length),
          itemBuilder: (ctx, raw) {
            // Flatten: [header, item, item, header, item, ...]
            int i = 0;
            for (final entry in groups.entries) {
              if (i == raw) return _buildDateHeader(entry.key);
              i++;
              for (final call in entry.value) {
                if (i == raw) return _CallCard(call: call);
                i++;
              }
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppColors.purple)),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppColors.divider, height: 1)),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          gradient: AppColors.pinkPurpleGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.pink.withValues(alpha: 0.25),
                blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: const Icon(Icons.phone_missed_rounded,
            color: Colors.white, size: 40),
      ),
      const SizedBox(height: 20),
      Text('No calls yet',
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      Text('Your call history will appear here',
          style: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textHint)),
    ]));
  }
}

// ── Individual Call Card ────────────────────────────────────────────────────

class _CallCard extends StatelessWidget {
  final CallModel call;
  const _CallCard({required this.call});

  bool get _isVideo => call.type == 'VIDEO';

  // Audio = blue-purple, Video = pink-purple
  List<Color> get _gradientColors => _isVideo
      ? [AppColors.pink, AppColors.purple]
      : [AppColors.blue, AppColors.purple];

  Color get _accentColor => _isVideo ? AppColors.pink : AppColors.blue;

  Color _statusColor(String s) {
    switch (s) {
      case 'COMPLETED': return AppColors.success;
      case 'MISSED':    return AppColors.busy;
      case 'REJECTED':
      case 'CANCELLED':
      case 'FAILED':    return AppColors.error;
      default:          return AppColors.textHint;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'COMPLETED': return Icons.call_received_rounded;
      case 'MISSED':    return Icons.call_missed_rounded;
      case 'REJECTED':  return Icons.call_end_rounded;
      case 'CANCELLED': return Icons.cancel_rounded;
      default:          return Icons.call_rounded;
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
    if (secs <= 0) return '';
    if (secs < 60) return '${secs}s';
    final m = secs ~/ 60, s = secs % 60;
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(call.status);
    final hasDuration = (call.durationSeconds ?? 0) > 0;
    final hasCoins    = (call.coinsDeducted ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.08),
            blurRadius: 16, spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        // ── Main Row ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // ── Avatar with gradient ring ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _gradientColors),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: _accentColor.withValues(alpha: 0.1),
                  backgroundImage: call.listenerPhoto != null
                      ? NetworkImage(call.listenerPhoto!)
                      : null,
                  child: call.listenerPhoto == null
                      ? Text(
                          call.listenerName.isNotEmpty
                              ? call.listenerName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: _accentColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ── Middle: name + type + time ─────────────────────────────
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.listenerName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(children: [
                  // Call type chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: _gradientColors),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        _isVideo
                            ? Icons.videocam_rounded
                            : Icons.mic_rounded,
                        color: Colors.white, size: 10,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _isVideo ? 'Video' : 'Voice',
                        style: GoogleFonts.poppins(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.access_time_rounded,
                      size: 11, color: AppColors.textHint),
                  const SizedBox(width: 3),
                  Text(
                    DateFormat('dd MMM, hh:mm a').format(call.createdAt),
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppColors.textHint),
                  ),
                ]),
              ],
            )),

            const SizedBox(width: 10),

            // ── Right: status + duration ──────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status icon + label
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon(call.status),
                      color: statusColor, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    _statusLabel(call.status),
                    style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ]),
                if (hasDuration) ...[
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.timer_outlined,
                        size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      _duration,
                      style: GoogleFonts.poppins(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ]),
        ),

        // ── Bottom strip: coins + call-again ─────────────────────────
        if (hasCoins)
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              // Coins spent
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.monetization_on_rounded,
                      size: 13, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Text(
                    '${call.coinsDeducted!.toStringAsFixed(0)} coins spent',
                    style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                ]),
              ),
              const Spacer(),
              // Call again button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _gradientColors),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withValues(alpha: 0.25),
                      blurRadius: 8, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                    color: Colors.white, size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Call Again',
                    style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}
