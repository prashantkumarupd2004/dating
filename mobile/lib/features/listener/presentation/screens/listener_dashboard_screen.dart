import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/services/ringtone_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';
import 'incoming_call_screen.dart';

class ListenerDashboardScreen extends StatefulWidget {
  const ListenerDashboardScreen({super.key});
  @override
  State<ListenerDashboardScreen> createState() => _ListenerDashboardScreenState();
}

// Safe parsers — Prisma Decimal serializes as String in JSON
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


class _ListenerDashboardScreenState extends State<ListenerDashboardScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _summary;
  bool _loading = false;
  bool _isOnline = false;
  String? _listenerId;

  // ── Presence heartbeat ─────────────────────────────────────────────────
  /// Keeps the Redis presence key alive while the listener is ONLINE.
  /// Backend TTL is 35s; we send a heartbeat every 25s to stay ahead.
  Timer? _presenceHeartbeatTimer;

  static const _presenceHeartbeatInterval = Duration(seconds: 25);

  // ── Incoming-call state ────────────────────────────────────────────────────
  /// The callId currently shown in the incoming-call dialog (null = no dialog).
  String? _activeIncomingCallId;

  /// Set of callIds we have already processed; prevents duplicate dialogs when
  /// both a socket event AND an FCM message arrive for the same call.
  final Set<String> _processedCallIds = {};

  bool _isTogglingStatus = false;
  DateTime? _lastRefresh;

  // ── Stored handler references — needed for precise removeListener() ────────
  late final Function(dynamic) _onIncomingCall;
  late final Function(dynamic) _onCallEnded;
  late final Function(dynamic) _onCallCancelled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Store handler references so we can remove exactly these later.
    _onIncomingCall  = _handleIncomingCall;
    _onCallEnded     = _handleCallEnded;
    _onCallCancelled = _handleCallCancelled;

    // Register listeners once. SocketService stores them and replays on
    // reconnect automatically, so there is no risk of duplicates.
    socketService.addListener('call:incoming',  _onIncomingCall);
    socketService.addListener('call:ended',     _onCallEnded);
    socketService.addListener('call:cancelled', _onCallCancelled);

    _load();
  }

  /// When the app returns to foreground while the listener is ONLINE,
  /// immediately re-announce presence so the Redis key is refreshed and
  /// the online status indicator doesn't flicker offline.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isOnline && _listenerId != null) {
      debugPrint('[PRESENCE] App resumed — re-announcing presence for $_listenerId');
      socketService.goOnline(_listenerId!);
    }
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (_loading) {
      debugPrint('⏸️ [Dashboard] Already loading, skipping...');
      return;
    }

    // Prevent rapid refresh — only allow every 30 s after first success.
    if (_lastRefresh != null && _summary != null) {
      final ago = DateTime.now().difference(_lastRefresh!);
      if (ago.inSeconds < 30) {
        debugPrint('⏸️ [Dashboard] Skipping refresh — last was ${ago.inSeconds}s ago');
        return;
      }
    }

    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // Earnings summary
      try {
        final resp = await api.get(ApiEndpoints.earningsSummary);
        if (mounted) setState(() { _summary = resp.data['data']; });
      } catch (e) {
        debugPrint('Earnings API error: $e');
      }

      // Listener profile
      try {
        final resp = await api.get(ApiEndpoints.listenerMe);
        final listenerData = resp.data['data'];
        final status = listenerData['onlineStatus'] as String? ?? 'OFFLINE';
        _listenerId = listenerData['id'] as String?;
        if (mounted) setState(() => _isOnline = status == 'ONLINE');

        // Ensure socket is connected and presence is announced.
        if (_isOnline && _listenerId != null) {
          await socketService.goOnline(_listenerId!);
          // Also start the presence heartbeat if not already running.
          // This handles the case where the app was killed and reopened
          // while the listener was ONLINE.
          _startPresenceHeartbeat();
        }
      } catch (e) {
        debugPrint('Listener Me API error: $e');
        if (e.toString().contains('404') && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete listener registration first'),
              backgroundColor: AppColors.error,
            ),
          );
          context.go('/listener/register');
          return;
        }
      }

      _lastRefresh = DateTime.now();
    } catch (e) {
      debugPrint('❌ Dashboard load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Incoming-call handlers ─────────────────────────────────────────────────

  void _handleIncomingCall(dynamic data) {
    final callId = data['callId'] as String?;
    if (callId == null) return;

    // Atomic deduplication: if already processing this callId, bail out.
    if (_processedCallIds.contains(callId)) {
      debugPrint('🔁 [Dashboard] Duplicate call:incoming for $callId — ignored');
      return;
    }
    // If a dialog is already showing for any call, ignore new events
    // (prevents stacking dialogs if the backend fires multiple events).
    if (_activeIncomingCallId != null) {
      debugPrint('🔁 [Dashboard] Already showing incoming call — ignored new $callId');
      return;
    }

    _processedCallIds.add(callId);
    _activeIncomingCallId = callId;

    debugPrint('📞 [Dashboard] Showing incoming call dialog for $callId');
    RingtoneService.playIncoming();

    // IMPORTANT: We pass the dialog's own BuildContext (ctx) into the callbacks
    // so that Navigator.pop(ctx, result) closes *this* dialog — NOT the app.
    // We must never call context.push() while the dialog is still open, because
    // GoRouter + Navigator operating on the stack at the same time causes a crash.
    showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      pageBuilder: (ctx, _, __) => IncomingCallScreen(
        callerName: data['callerName'] as String? ?? 'Unknown Caller',
        callType:   data['callType']   as String? ?? 'AUDIO',
        callerPhoto: data['callerPhoto'] as String?,
        onAccept: () {
          // Close dialog with a sentinel value so .then() knows to accept.
          RingtoneService.stop();
          Navigator.of(ctx, rootNavigator: true).pop({'action': 'accept'});
        },
        onDecline: () {
          // Close dialog with a sentinel so .then() knows to reject.
          RingtoneService.stop();
          Navigator.of(ctx, rootNavigator: true).pop({'action': 'decline'});
        },
      ),
    ).then((result) async {
      // Dialog is FULLY closed here — safe to navigate.
      if (_activeIncomingCallId == callId) _activeIncomingCallId = null;

      if (result == null) return; // tapped barrier or dismissed

      if (result['action'] == 'decline') {
        // Fire-and-forget reject API.
        Future(() async {
          try { await api.post(ApiEndpoints.rejectCall(callId)); } catch (_) {}
        });
        return;
      }

      if (result['action'] == 'accept') {
        await _acceptCall(data);
      }
    });
  }

  void _handleCallEnded(dynamic data) {
    final callId = data['callId'] as String?;
    debugPrint('📴 [Dashboard] call:ended received for $callId (active: $_activeIncomingCallId)');
    if (callId != null && callId == _activeIncomingCallId) {
      _dismissIncomingDialog();
    }
  }

  void _handleCallCancelled(dynamic data) {
    final callId = data['callId'] as String?;
    debugPrint('❌ [Dashboard] call:cancelled received for $callId (active: $_activeIncomingCallId)');
    if (callId != null && callId == _activeIncomingCallId) {
      _dismissIncomingDialog();
    }
  }

  void _dismissIncomingDialog() {
    RingtoneService.stop();
    if (_activeIncomingCallId != null && mounted) {
      debugPrint('🔕 [Dashboard] Dismissing incoming call dialog');
      try {
        // Pop with null result — .then() handler will see null and skip navigation.
        Navigator.of(context, rootNavigator: true).pop(null);
      } catch (_) {
        // Dialog may already be gone — safe to ignore.
      }
    }
    _activeIncomingCallId = null;
  }

  // ── Accept call ────────────────────────────────────────────────────────────
  // Called from showGeneralDialog .then() — dialog is already closed at this point,
  // so context.push() is safe (no Navigator stack conflict).

  Future<void> _acceptCall(dynamic data) async {
    final callId = data['callId'] as String? ?? '';
    try {
      final resp = await api.post(ApiEndpoints.acceptCall(callId));
      if (!mounted) return;

      final call = resp.data['data'] as Map<String, dynamic>? ?? {};

      // Validate required Agora fields before navigating.
      final channelId  = call['channelId']  as String?;
      final agoraToken = call['agoraToken'] as String?;
      final agoraAppId = call['agoraAppId'] as String?;
      // uid may come as int, double, or String from backend — normalise safely.
      final uid        = _toInt(call['listenerUid']);
      final callRouteId = call['id'] as String? ?? callId;

      if (channelId == null || agoraToken == null || agoraAppId == null) {
        debugPrint('❌ [_acceptCall] Missing Agora fields: $call');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call setup failed — missing Agora config')),
          );
        }
        return;
      }

      context.push(
        call['type'] == 'VIDEO' ? '/call/video' : '/call/audio',
        extra: {
          'mode':         'listener',
          'callId':       callRouteId,
          'channelId':    channelId,
          'agoraToken':   agoraToken,
          'agoraAppId':   agoraAppId,
          'uid':          uid,
          'listenerName': data['callerName'] ?? 'Someone',
        },
      );
    } catch (e) {
      debugPrint('❌ [_acceptCall] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not accept call: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ── Toggle online/offline ──────────────────────────────────────────────────

  Future<void> _toggleOnline() async {
    debugPrint('🔵 [Toggle] Called - isToggling: $_isTogglingStatus');
    if (_isTogglingStatus) return;

    setState(() => _isTogglingStatus = true);
    final newStatus = _isOnline ? 'OFFLINE' : 'ONLINE';

    try {
      await api.patch(ApiEndpoints.listenerStatus, data: {'status': newStatus});
      if (!mounted) return;

      setState(() => _isOnline = !_isOnline);

      if (newStatus == 'ONLINE') {
        if (_listenerId != null) await socketService.goOnline(_listenerId!);
        _startPresenceHeartbeat();
      } else {
        socketService.goOffline();
        _stopPresenceHeartbeat();
        // Clear processed calls when going offline.
        _processedCallIds.clear();
      }
    } catch (e) {
      debugPrint('❌ Toggle status error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _isTogglingStatus = false);
    }
  }

  // ── Presence heartbeat helpers ──────────────────────────────────────────

  void _startPresenceHeartbeat() {
    _stopPresenceHeartbeat(); // idempotent — clear any existing timer first
    debugPrint('[PRESENCE_HB] Starting heartbeat timer (interval: ${_presenceHeartbeatInterval.inSeconds}s)');
    _presenceHeartbeatTimer = Timer.periodic(_presenceHeartbeatInterval, (_) {
      if (_isOnline) {
        socketService.heartbeat();
        debugPrint('[PRESENCE_HB] ✓ Sent presence:heartbeat');
      } else {
        _stopPresenceHeartbeat();
      }
    });
  }

  void _stopPresenceHeartbeat() {
    if (_presenceHeartbeatTimer != null) {
      debugPrint('[PRESENCE_HB] Stopping heartbeat timer');
      _presenceHeartbeatTimer!.cancel();
      _presenceHeartbeatTimer = null;
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPresenceHeartbeat();
    // Remove exactly our handlers — does not affect any other widget's listeners.
    socketService.removeListener('call:incoming',  _onIncomingCall);
    socketService.removeListener('call:ended',     _onCallEnded);
    socketService.removeListener('call:cancelled', _onCallCancelled);
    super.dispose();
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '0m';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final recentCalls = (_summary?['recentCalls'] as List?) ?? [];

    return GradientScaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Header
            Row(children: [
              Expanded(child: Text('Dashboard', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: (_isOnline ? AppColors.online : AppColors.offline).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _isOnline ? AppColors.online : AppColors.offline, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(_isOnline ? 'Online' : 'Offline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isOnline ? AppColors.online : AppColors.offline)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),

            // GO ONLINE / GO OFFLINE button
            GestureDetector(
              onTap: _toggleOnline,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: _isOnline
                      ? const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF388E3C)])
                      : AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: (_isOnline ? AppColors.online : AppColors.accentStart).withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_isOnline ? Icons.wifi_off : Icons.wifi, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(_isOnline ? 'GO OFFLINE' : 'GO ONLINE', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.8)),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            if (_loading)
              const Center(child: CircularProgressIndicator(color: AppColors.primary))
            else ...[

              // Today's Stats
              Text("Today's Stats", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(children: [
                _statCard("Today's Earnings", '₹${_toDouble(_summary?['todayEarnings']).toStringAsFixed(0)}', Icons.trending_up, AppColors.success),
                const SizedBox(width: 12),
                _statCard("Today's Calls", '${_toInt(_summary?['todayCalls'])}', Icons.call_rounded, AppColors.primary),
              ]),
              const SizedBox(height: 12),

              // Overall Stats
              Text("Overall Stats", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(children: [
                _statCard('Total Earnings', '₹${_toDouble(_summary?['totalEarnings']).toStringAsFixed(0)}', Icons.account_balance_wallet, AppColors.accentStart),
                const SizedBox(width: 12),
                _statCard('Total Calls', '${_toInt(_summary?['totalCalls'])}', Icons.history, AppColors.gold),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _statCard('This Week', '₹${_toDouble(_summary?['weekEarnings']).toStringAsFixed(0)}', Icons.date_range, AppColors.purple),
                const SizedBox(width: 12),
                _statCard('Available', '₹${_toDouble(_summary?['availableBalance']).toStringAsFixed(0)}', Icons.savings, AppColors.primary),
              ]),
              const SizedBox(height: 20),

              // Payout Button
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () => context.push('/listener/payout'),
                icon: const Icon(Icons.arrow_upward, size: 18),
                label: const Text('Request Payout'),
              )),
              const SizedBox(height: 24),

              // Recent Calls
              Text('Recent Calls', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              if (recentCalls.isEmpty)
                AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(children: [
                        const Icon(Icons.call_outlined, size: 36, color: AppColors.textHint),
                        const SizedBox(height: 8),
                        Text('No completed calls yet', style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 13)),
                      ]),
                    ),
                  ),
                )
              else
                ...recentCalls.map((call) => _recentCallCard(call as Map<String, dynamic>)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) => Expanded(
    child: AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 17)),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.poppins(color: AppColors.textHint, fontSize: 10)),
      ]),
    ),
  );

  Widget _recentCallCard(Map<String, dynamic> call) {
    final isAudio = call['type'] == 'AUDIO';
    final callerName = call['user']?['name'] ?? 'Unknown';
    final duration = _formatDuration(call['durationSeconds'] as int?);
    final createdAt = call['createdAt'] != null
        ? DateTime.tryParse(call['createdAt'])?.toLocal()
        : null;
    final timeStr = createdAt != null
        ? '${createdAt.day}/${createdAt.month} ${createdAt.hour.toString().padLeft(2,'0')}:${createdAt.minute.toString().padLeft(2,'0')}'
        : '';

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            gradient: isAudio ? AppColors.pinkPurpleGradient : AppColors.callBtnGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(isAudio ? Icons.mic_rounded : Icons.videocam_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(callerName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
          Text('${isAudio ? 'Audio' : 'Video'} • $duration', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        Text(timeStr, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint)),
      ]),
    );
  }
}
