import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/wallet_provider.dart';
import '../../../../core/services/ringtone_service.dart';
import '../../../../core/services/call_state_store.dart';
import '../../../../core/services/call_heartbeat_service.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/theme/call_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
class AudioCallScreen extends StatefulWidget {
  final Map<String, dynamic> extra;
  const AudioCallScreen({super.key, required this.extra});
  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Agora / call state ────────────────────────────────────────────────────
  RtcEngine? _engine;
  String? _callId;
  bool _inCall = false;
  bool _muted = false;
  bool _speakerOn = false;
  int _seconds = 0;
  bool _loading = true;
  String? _error;
  Timer? _timer;
  Timer? _connectionTimeout;
  bool _ended = false;
  bool _navigatedAway = false; // prevent double pop

  // Buffer for call:ended events that arrive before we receive our callId from the
  // initiateCall API response. Without this, a very fast decline by the listener
  // causes the event to be dropped (callId null check) and the user is stuck connecting.
  final List<Map<String, dynamic>> _pendingEndEvents = [];

  // ── Method channel for native foreground service ──────────────────────────
  static const _platform = MethodChannel('com.milan.datingapp/call_foreground');

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _pulseCtrl;    // caller avatar ripple
  late AnimationController _waveCtrl;     // waveform shimmer
  late AnimationController _dotCtrl;      // connecting dots
  late AnimationController _ringCtrl;     // central call button rings
  late Animation<double> _pulseAnim;
  late Animation<double> _waveAnim;
  late Animation<double> _dotAnim;
  late Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);

    // ── Animations ────────────────────────────────────────────────────────
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _waveCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
    _dotCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _ringCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _waveAnim  = Tween<double>(begin: 0.0, end: 1.0).animate(_waveCtrl);
    _dotAnim   = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut));
    _ringAnim  = Tween<double>(begin: 0.0, end: 1.0).animate(_ringCtrl);

    socketService.on('call:ended', _handleCallEnded);
    _startCall();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Keep the call active when backgrounded/resumed — do NOT call leaveChannel
    // The foreground service will keep the process alive
    if (state == AppLifecycleState.resumed) {
      // Ensure audio is not muted when returning to foreground
      if (_engine != null && _inCall) {
        _engine?.muteLocalAudioStream(_muted);
      }
    }
  }

  // ── Call logic ───────────────────────────────────────────────────────────────

  /// Safely convert any JSON numeric value (int, double, String) to int.
  /// Returns 0 as safe fallback so Agora gets a valid uid and doesn't throw.
  static int _safeUid(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _startCall() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (!mounted) return;
      setState(() { _error = 'Microphone permission is required'; _loading = false; });
      return;
    }
    try {
      // ── RESTORATION PATH (BUG 3 FIX) ──────────────────────────────────────
      // When the user taps the active-call notification, main.dart calls
      // _tryRestoreActiveCall() which pushes the call screen with
      // extra['restored'] = true and all Agora params already stored.
      // In this case we must NOT call initiateCall (it would create a new
      // call and fail because the listener is BUSY). Instead, go straight
      // to _joinAgora() with the persisted params.
      if (widget.extra['restored'] == true) {
        debugPrint('[CALL_RESTORE] Restored from notification — skipping initiateCall API');
        final channelId  = widget.extra['channelId']  as String?;
        final agoraToken = widget.extra['agoraToken'] as String?;
        final agoraAppId = widget.extra['agoraAppId'] as String?;
        _callId          = widget.extra['callId']     as String? ?? '';
        if (channelId == null || agoraToken == null || agoraAppId == null || _callId!.isEmpty) {
          setState(() { _error = 'Cannot restore call — missing session data'; _loading = false; });
          return;
        }
        await _joinAgora(channelId, agoraToken, agoraAppId, _safeUid(widget.extra['uid']));
        return;
      }

      // ── LISTENER PATH ──────────────────────────────────────────────────────
      if (widget.extra['mode'] == 'listener') {
        final channelId  = widget.extra['channelId']  as String?;
        final agoraToken = widget.extra['agoraToken'] as String?;
        final agoraAppId = widget.extra['agoraAppId'] as String?;
        _callId          = widget.extra['callId']     as String? ?? '';
        if (channelId == null || agoraToken == null || agoraAppId == null) {
          setState(() { _error = 'Invalid call config (missing Agora params)'; _loading = false; });
          return;
        }
        await _joinAgora(channelId, agoraToken, agoraAppId, _safeUid(widget.extra['uid']));
        return;
      }

      // ── USER / CALLER PATH ────────────────────────────────────────────────
      final resp = await api.post(ApiEndpoints.initiateCall, data: {
        'listenerId': widget.extra['listenerId'],
        'callType': 'AUDIO',
      });
      final data = resp.data['data'] as Map<String, dynamic>? ?? {};

      final channelId  = data['channelId']  as String?;
      final agoraToken = data['agoraToken'] as String?;
      final agoraAppId = data['agoraAppId'] as String?;
      _callId          = data['callId']     as String? ?? '';

      if (channelId == null || agoraToken == null || agoraAppId == null) {
        setState(() { _error = 'Call setup failed — missing Agora config from server'; _loading = false; });
        return;
      }

      // Check if a call:ended event arrived before we got this API response
      // (e.g. listener declined very quickly). If so, handle it and skip Agora join.
      if (_processPendingEndEvents()) return;

      await _joinAgora(channelId, agoraToken, agoraAppId, _safeUid(data['userUid']));
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to start call: $e'; _loading = false; });
    }
  }

  Future<void> _joinAgora(String channel, String token, String appId, int uid) async {
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));
    await _engine!.enableAudio();
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (_, __) async {
        if (mounted) setState(() => _loading = false);
        // ── Persist call state so it survives process death ────────────────
        final mode    = widget.extra['mode'] as String? ?? 'user';
        const callType = 'AUDIO';
        if (_callId != null && _callId!.isNotEmpty) {
          await CallStateStore.instance.save(
            callId:       _callId!,
            channelId:    channel,
            agoraToken:   token,
            agoraAppId:   appId,
            uid:          uid,
            callType:     callType,
            mode:         mode,
            listenerName: widget.extra['listenerName'] as String? ?? 'Call',
          );
          debugPrint('[CALL_CONNECTED] callId=$_callId mode=$mode');

          // ── Start heartbeat so watchdog knows we are alive ───────────────
          // role: 'listener' if this client is the listener, else 'user'
          final heartbeatRole = mode == 'listener' ? 'listener' : 'user';
          CallHeartbeatService.instance.start(callId: _callId!, role: heartbeatRole);
          debugPrint('[CALL_HEARTBEAT] Started: callId=$_callId role=$heartbeatRole');
        }

        // Start foreground service
        try {
          final callerName = widget.extra['listenerName'] as String? ?? 'Call';
          await _platform.invokeMethod('startCallForeground', {
            'callerName': callerName,
            'callType': 'audio',
          });
          debugPrint('[SERVICE_START] Call foreground service started');
        } catch (e) {
          // Ignore — foreground service is optional
        }
        if (widget.extra['mode'] != 'listener') RingtoneService.playRingback();
        _connectionTimeout = Timer(const Duration(seconds: 60), () {
          if (!_inCall && !_ended && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Connection timeout - no answer'))
            );
            _endCall();
          }
        });
      },
      onUserJoined:         (_, __, ___) {
        if (!mounted) return;
        _connectionTimeout?.cancel();
        RingtoneService.stop(); // listener picked up — stop ringback
        setState(() => _inCall = true);
        _startTimer();
      },
      onUserOffline:        (_, __, ___) { if (!mounted) return; _endCall(remote: true); },
      onLeaveChannel:       (_, __) {},
    ));
    await _engine!.joinChannel(
      token: token,
      channelId: channel,
      uid: uid,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
    if (mounted) setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _seconds++); });
  }

  Future<void> _endCall({bool remote = false}) async {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    _connectionTimeout?.cancel();
    RingtoneService.stop(); // stop ringback if listener never answered

    // Stop foreground service
    try {
      await _platform.invokeMethod('stopCallForeground');
    } catch (_) {
      // Ignore — service may already be stopped
    }

    final engine = _engine;
    _engine = null;

    // Add timeout so Agora SDK never hangs the UI
    try {
      await Future.wait([
        engine?.leaveChannel() ?? Future.value(),
      ]).timeout(const Duration(seconds: 3));
      await Future.wait([
        engine?.release() ?? Future.value(),
      ]).timeout(const Duration(seconds: 3));
    } catch (_) {}

    if (_callId != null) {
      try {
        await api.post(ApiEndpoints.endCall(_callId!), data: {'endedBy': remote ? 'LISTENER' : 'USER'});
        walletProvider.fetchBalance(force: true);
      } catch (_) {}
    }
    // Stop heartbeat BEFORE clearing state so no stale beats land after end
    CallHeartbeatService.instance.stop();
    // Clear persisted call state — call is definitively over.
    await CallStateStore.instance.clear();
    debugPrint('[ACTIVE_CALL_CLEARED] _endCall complete');
    WakelockPlus.disable();
    await _navigateAfterCall();
  }

  /// Processes any buffered call:ended events after _callId is known.
  /// Returns true if a matching end event was found and handled (caller should
  /// NOT proceed to join Agora in that case).
  bool _processPendingEndEvents() {
    for (final event in _pendingEndEvents) {
      if (event['callId'] == _callId) {
        debugPrint('[CALL_END] Processing buffered call:ended callId=$_callId reason=${event['reason']}');
        _pendingEndEvents.clear();
        _handleCallEnded(event);
        return true;
      }
    }
    _pendingEndEvents.clear();
    return false;
  }

  void _handleCallEnded(dynamic data) {
    if (data is! Map) return;
    // If callId is not yet known, buffer the event and process it once we know.
    if (_callId == null) {
      _pendingEndEvents.add(Map<String, dynamic>.from(data as Map));
      debugPrint('[CALL_END] Buffered call:ended (callId not yet set): ${data['callId']}');
      return;
    }
    if (_ended || data['callId'] != _callId) return;
    _ended = true;
    _timer?.cancel();
    _connectionTimeout?.cancel();
    RingtoneService.stop();
    // Stop heartbeat immediately — the call is over
    CallHeartbeatService.instance.stop();
    final engine = _engine;
    _engine = null;
    Future(() async {
      try {
        await engine?.leaveChannel().timeout(const Duration(seconds: 3));
        await engine?.release().timeout(const Duration(seconds: 3));
      } catch (_) {}
      await CallStateStore.instance.clear();
      debugPrint('[ACTIVE_CALL_CLEARED] _handleCallEnded complete');
    });
    WakelockPlus.disable();
    if (!mounted || _navigatedAway) return;
    final reason = data['reason'] as String?;
    final msg = reason == 'missed' ? 'No answer'
      : reason == 'rejected'          ? 'Call declined'
      : reason == 'listener_timeout'  ? 'Listener disconnected'
      : reason == 'caller_timeout'    ? 'You were disconnected'
      : 'Call ended';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Future(() => _navigateAfterCall());
  }

  /// Shows "End call?" confirmation dialog.
  /// Returns true if the user confirmed ending the call, false/null otherwise.
  Future<bool?> _showEndCallConfirmation() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.call_end_rounded, color: Color(0xFFFF2D9B), size: 22),
          const SizedBox(width: 10),
          Text(
            'End call?',
            style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
            ),
          ),
        ]),
        content: Text(
          'Are you sure you want to end this call?',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.white54),
            child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2D2D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'End Call',
              style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show rating dialog (user-mode, connected calls only), then pop.

  Future<void> _navigateAfterCall() async {
    if (!mounted || _navigatedAway) return;
    _navigatedAway = true;

    final isUser = widget.extra['mode'] != 'listener';
    if (isUser && _inCall && _callId != null) {
      await _showRatingDialog();
    }

    if (mounted) context.pop();
  }

  Future<void> _showRatingDialog() async {
    int selected = 0;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: CallColors.neonPurple.withValues(alpha: 0.4), width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.call_end_rounded, color: CallColors.neonPink, size: 36),
              const SizedBox(height: 12),
              Text(
                'How was your experience?',
                style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Rate your listener',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 24),
              // Star row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < selected;
                  return GestureDetector(
                    onTap: () => setModal(() => selected = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_border_rounded,
                        color: filled ? const Color(0xFFFFD700) : Colors.white38,
                        size: 44,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('Skip', style: GoogleFonts.poppins(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selected > 0
                          ? () async {
                              Navigator.pop(ctx);
                              await _submitRating(selected);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CallColors.neonPurple,
                        disabledBackgroundColor: Colors.white12,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Submit',
                        style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRating(int rating) async {
    if (_callId == null) return;
    try {
      await api.post(ApiEndpoints.rateCall(_callId!), data: {'rating': rating});
    } catch (_) {
      // Silently ignore — rating failure should not block navigation
    }
  }

  String get _duration {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _dotCtrl.dispose();
    _ringCtrl.dispose();
    socketService.off('call:ended', _handleCallEnded);
    _timer?.cancel();
    _connectionTimeout?.cancel();
    if (!_ended) {
      // Safety net: if the widget is disposed without _endCall being called
      // (e.g. hot reload, unexpected navigation), clean up resources and
      // clear the persisted state so we don't show a stale "Return to Call".
      debugPrint('[CALL_END] dispose() called without _endCall — cleaning up');
      CallHeartbeatService.instance.stop();
      _platform.invokeMethod('stopCallForeground').catchError((_) {});
      _engine?.leaveChannel().catchError((_) {});
      _engine?.release().catchError((_) {});
      CallStateStore.instance.clear();
    }
    WakelockPlus.disable();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final listenerName = widget.extra['listenerName'] as String? ?? 'Listener';
    final photo        = widget.extra['listenerPhoto'] as String?;
    final city         = widget.extra['listenerCity'] as String? ?? 'Delhi';
    final age          = widget.extra['listenerAge'] as int?;
    final isListener   = widget.extra['mode'] == 'listener';

    if (_loading) return _loadingScreen();
    if (_error != null) return _errorScreen();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Show confirmation dialog — back press should NOT end call silently.
        final confirmed = await _showEndCallConfirmation();
        if (confirmed == true) _endCall();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: const BoxDecoration(gradient: CallColors.bgGradient),
            child: Stack(
              children: [
                // ── Radial ambient glow ────────────────────────────────────
                Positioned.fill(child: CustomPaint(painter: _AmbientGlowPainter())),
                // ── Main content ───────────────────────────────────────────
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _buildLogo(),
                      const SizedBox(height: 6),
                      _buildConnectingStatus(),
                      const SizedBox(height: 20),
                      _buildCallerAvatar(listenerName, photo, city, age),
                      const SizedBox(height: 16),
                      Expanded(child: _buildConnectionVisualization()),
                      _buildUserAvatar(isListener),
                      const SizedBox(height: 20),
                      _buildHeadphoneTip(),
                      const SizedBox(height: 12),
                      _buildCallControls(),
                      const SizedBox(height: 8),
                      // Android gesture bar
                      Center(
                        child: Container(
                          width: 120,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Subtle glow behind logo
        Container(
          width: 200,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: CallColors.neonPurple.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 5),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => CallColors.logoGradient.createShader(bounds),
              child: GoogleFonts.pacifico(
                fontSize: 32,
                color: Colors.white,
                shadows: [Shadow(color: CallColors.electricBlue.withValues(alpha: 0.5), blurRadius: 12)],
              ).copyWith(
                fontSize: 32,
              ).apply(
                color: Colors.white,
              ).let((style) => Text('Milan', style: style)),
            ),
            const SizedBox(width: 1),
            Text(
              '!',
              style: GoogleFonts.pacifico(
                fontSize: 32,
                color: CallColors.neonPink,
                shadows: [Shadow(color: CallColors.neonPink.withValues(alpha: 0.7), blurRadius: 12)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Connecting status ────────────────────────────────────────────────────
  Widget _buildConnectingStatus() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _dotAnim,
          builder: (_, __) => Opacity(
            opacity: _dotAnim.value,
            child: Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(color: CallColors.neonGreen, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _inCall ? _duration : 'Connecting...',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _inCall ? CallColors.neonGreen : Colors.white60,
            shadows: [Shadow(color: CallColors.neonGreen.withValues(alpha: 0.6), blurRadius: 10)],
          ),
        ),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: _dotAnim,
          builder: (_, __) => Opacity(
            opacity: 1.0 - _dotAnim.value + 0.3,
            child: Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(color: CallColors.neonGreen, shape: BoxShape.circle),
            ),
          ),
        ),
      ],
    );
  }

  // ── Caller avatar ─────────────────────────────────────────────────────────
  Widget _buildCallerAvatar(String name, String? photo, String city, int? age) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer ripple rings
                _rippleRing(size: 130 + (_pulseAnim.value * 30), opacity: (1 - _pulseAnim.value) * 0.25, color: CallColors.neonPink),
                _rippleRing(size: 120 + (_pulseAnim.value * 20), opacity: (1 - _pulseAnim.value) * 0.2,  color: CallColors.neonPurple),
                _rippleRing(size: 110 + (_pulseAnim.value * 10), opacity: (1 - _pulseAnim.value) * 0.3,  color: CallColors.neonPink),
                child!,
              ],
            );
          },
          child: _avatarCircle(photo, name, size: 96, borderColor: CallColors.neonPink, glowColor: CallColors.neonPink),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CallColors.neonPink.withValues(alpha: 0.4), width: 1),
          ),
          child: Text(
            '${age != null ? '$age Y • ' : ''}$city',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _inCall ? 'Connected' : 'Connecting...',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }

  // ── Connection visualization (center) ────────────────────────────────────
  Widget _buildConnectionVisualization() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Waveform behind everything
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _waveAnim,
                builder: (_, __) => CustomPaint(
                  painter: _WaveformPainter(animValue: _waveAnim.value),
                ),
              ),
            ),
            // Vertical dot connectors
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildConnectorDots(up: true),
                // Central call button
                AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (_, child) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // Expanding ripple rings
                      _rippleRing(size: 72 + (_ringAnim.value * 50), opacity: (1 - _ringAnim.value) * 0.3, color: CallColors.electricBlue),
                      _rippleRing(size: 72 + ((_ringAnim.value + 0.33) % 1.0 * 50), opacity: (1 - (_ringAnim.value + 0.33) % 1.0) * 0.25, color: CallColors.neonPurple),
                      _rippleRing(size: 72 + ((_ringAnim.value + 0.66) % 1.0 * 50), opacity: (1 - (_ringAnim.value + 0.66) % 1.0) * 0.2, color: CallColors.electricBlue),
                      child!,
                    ],
                  ),
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [CallColors.electricBlue, CallColors.neonPurple],
                        center: Alignment(0.0, -0.3),
                      ),
                      boxShadow: [
                        BoxShadow(color: CallColors.electricBlue.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 2),
                        BoxShadow(color: CallColors.neonPurple.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.call_rounded, color: Colors.white, size: 30),
                  ),
                ),
                _buildConnectorDots(up: false),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectorDots({required bool up}) {
    return Column(
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _dotCtrl,
          builder: (_, __) {
            final delay = i / 3.0;
            final t = (_dotCtrl.value + delay) % 1.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Opacity(
                opacity: up ? (i == 2 ? t : i == 1 ? (t + 0.33) % 1.0 : (t + 0.66) % 1.0)
                            : (i == 0 ? t : i == 1 ? (t + 0.33) % 1.0 : (t + 0.66) % 1.0),
                child: Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: CallColors.electricBlue,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: CallColors.electricBlue.withValues(alpha: 0.8), blurRadius: 6)],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // ── User avatar ───────────────────────────────────────────────────────────
  Widget _buildUserAvatar(bool isListener) {
    final userCity = widget.extra['userCity'] as String?;
    return Column(
      children: [
        _avatarCircle(null, isListener ? 'L' : 'Y', size: 80,
            borderColor: CallColors.electricBlue, glowColor: CallColors.neonPurple,
            isUser: true),
        const SizedBox(height: 10),
        Text('You', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 5),
        if (userCity != null && userCity.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CallColors.electricBlue.withValues(alpha: 0.4), width: 1),
            ),
            child: Text(userCity, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white60)),
          ),
      ],
    );
  }

  // ── Headphone tip ─────────────────────────────────────────────────────────
  Widget _buildHeadphoneTip() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CallColors.neonPurple.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(color: CallColors.neonPurple.withValues(alpha: 0.08), blurRadius: 16),
        ],
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [CallColors.neonPink, CallColors.neonPurple],
            ).createShader(b),
            child: const Icon(Icons.headphones_rounded, size: 26, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Use Headphones for', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [CallColors.neonPink, CallColors.neonPurple],
                  ).createShader(b),
                  child: Text(
                    'Better Calling Experience',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Mini waveform decoration
          CustomPaint(painter: _MiniWaveformPainter(), size: const Size(50, 24)),
        ],
      ),
    );
  }

  // ── Call controls ─────────────────────────────────────────────────────────
  Widget _buildCallControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _controlBtn(
            icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _muted ? 'Unmute' : 'Mute',
            active: _muted,
            onTap: () => setState(() { _muted = !_muted; _engine?.muteLocalAudioStream(_muted); }),
          ),
          _endCallBtn(),
          _controlBtn(
            icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
            label: 'Speaker',
            active: _speakerOn,
            onTap: () => setState(() { _speakerOn = !_speakerOn; _engine?.setEnableSpeakerphone(_speakerOn); }),
          ),
        ],
      ),
    );
  }

  Widget _controlBtn({required IconData icon, required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? CallColors.neonPurple.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: active ? CallColors.neonPurple : CallColors.electricBlue.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: active
                  ? [BoxShadow(color: CallColors.neonPurple.withValues(alpha: 0.3), blurRadius: 12)]
                  : null,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _endCallBtn() {
    return GestureDetector(
      onTap: () => _endCall(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF2D2D), Color(0xFFFF2D9B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF2D2D).withValues(alpha: 0.55), blurRadius: 24, spreadRadius: 2),
                BoxShadow(color: CallColors.neonPink.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 4),
              ],
            ),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text('End Call', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _avatarCircle(String? photo, String name, {
    required double size,
    required Color borderColor,
    required Color glowColor,
    bool isUser = false,
  }) {
    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(color: glowColor.withValues(alpha: 0.45), blurRadius: 20, spreadRadius: 2),
          BoxShadow(color: glowColor.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 4),
        ],
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: CallColors.surface,
        backgroundImage: photo != null ? NetworkImage(photo) : null,
        child: photo == null
            ? (isUser
                ? const Icon(Icons.person_rounded, size: 42, color: Colors.white70)
                : Text(name[0].toUpperCase(),
                    style: GoogleFonts.poppins(fontSize: size * 0.35, fontWeight: FontWeight.w700, color: borderColor)))
            : null,
      ),
    );
  }

  Widget _rippleRing({required double size, required double opacity, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: opacity.clamp(0.0, 1.0)), width: 1.5),
      ),
    );
  }

  // ── Loading & error screens ───────────────────────────────────────────────
  Widget _loadingScreen() {
    final listenerName = widget.extra['listenerName'] as String? ?? 'Listener';
    final photo        = widget.extra['listenerPhoto'] as String?;
    final city         = widget.extra['listenerCity'] as String? ?? '';
    final age          = widget.extra['listenerAge'] as int?;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(gradient: CallColors.bgGradient),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _AmbientGlowPainter())),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildLogo(),
                    const SizedBox(height: 12),
                    // Animated connecting dots row
                    AnimatedBuilder(
                      animation: _dotAnim,
                      builder: (_, __) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: _dotAnim.value,
                            child: Container(width: 6, height: 6,
                              decoration: const BoxDecoration(color: CallColors.neonPink, shape: BoxShape.circle)),
                          ),
                          const SizedBox(width: 8),
                          Text('Connecting...',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600,
                              color: Colors.white60,
                              shadows: [Shadow(color: CallColors.neonPink.withValues(alpha: 0.5), blurRadius: 10)])),
                          const SizedBox(width: 8),
                          Opacity(
                            opacity: 1.0 - _dotAnim.value + 0.3,
                            child: Container(width: 6, height: 6,
                              decoration: const BoxDecoration(color: CallColors.neonPink, shape: BoxShape.circle)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Pulsing listener avatar
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Stack(
                        alignment: Alignment.center,
                        children: [
                          _rippleRing(size: 130 + (_pulseAnim.value * 30), opacity: (1 - _pulseAnim.value) * 0.25, color: CallColors.neonPink),
                          _rippleRing(size: 120 + (_pulseAnim.value * 20), opacity: (1 - _pulseAnim.value) * 0.2,  color: CallColors.neonPurple),
                          _rippleRing(size: 110 + (_pulseAnim.value * 10), opacity: (1 - _pulseAnim.value) * 0.3,  color: CallColors.neonPink),
                          child!,
                        ],
                      ),
                      child: _avatarCircle(photo, listenerName, size: 96,
                        borderColor: CallColors.neonPink, glowColor: CallColors.neonPink),
                    ),
                    const SizedBox(height: 16),
                    Text(listenerName,
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    if (city.isNotEmpty || age != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: CallColors.neonPink.withValues(alpha: 0.4), width: 1),
                        ),
                        child: Text(
                          '${age != null ? '$age Y • ' : ''}$city',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                    const Spacer(),
                    // Waveform animation
                    AnimatedBuilder(
                      animation: _waveAnim,
                      builder: (_, __) => CustomPaint(
                        painter: _WaveformPainter(animValue: _waveAnim.value),
                        size: const Size(double.infinity, 60),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // End call button while connecting
                    _endCallBtn(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorScreen() {
    return Scaffold(
      backgroundColor: CallColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: CallColors.bgGradient),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: CallColors.neonPink, size: 52),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [CallColors.electricBlue, CallColors.neonPurple]),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text('Go Back', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painters
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen ambient radial glow
class _AmbientGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top purple bloom
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.18),
      size.width * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF9B59B6).withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.18), radius: size.width * 0.7)),
    );
    // Bottom blue bloom
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.75),
      size.width * 0.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF4F6EFF).withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.75), radius: size.width * 0.6)),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Full-width audio waveform with pink→purple→blue gradient
class _WaveformPainter extends CustomPainter {
  final double animValue;
  _WaveformPainter({required this.animValue});

  static const _heights = [
    0.3, 0.6, 0.9, 0.5, 0.8, 0.4, 0.7, 1.0, 0.6, 0.4,
    0.8, 0.5, 0.9, 0.7, 0.3, 0.6, 1.0, 0.4, 0.8, 0.5,
    0.7, 0.9, 0.4, 0.6, 1.0, 0.5, 0.8, 0.3, 0.7, 0.6,
    0.9, 0.4, 0.8, 0.5, 0.7, 1.0, 0.3, 0.6, 0.9, 0.4,
    0.8, 0.5, 0.7, 1.0, 0.6, 0.3, 0.8, 0.5, 0.9, 0.4,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxH = size.height * 0.38;
    const barW = 3.5;
    const gap  = 5.5;
    final total = _heights.length;
    final totalW = total * (barW + gap);
    final startX = cx - totalW / 2;
    const centerRadius = 42.0; // don't draw bars over central button

    for (int i = 0; i < total; i++) {
      final x = startX + i * (barW + gap) + barW / 2;
      if ((x - cx).abs() < centerRadius) continue;

      // Animate height slightly
      final phase = (i / total + animValue) % 1.0;
      final h = _heights[i % _heights.length] * maxH * (0.7 + 0.3 * math.sin(phase * math.pi * 2));

      // Color: pink left, purple center, blue right
      final t = i / total;
      Color barColor;
      if (t < 0.4) {
        barColor = Color.lerp(const Color(0xFFFF2D9B), const Color(0xFF9B59B6), t / 0.4)!;
      } else if (t < 0.6) {
        barColor = const Color(0xFF9B59B6);
      } else {
        barColor = Color.lerp(const Color(0xFF9B59B6), const Color(0xFF4F6EFF), (t - 0.6) / 0.4)!;
      }

      final paint = Paint()
        ..color = barColor.withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, cy), width: barW, height: h),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.animValue != animValue;
}

/// Small pink/blue mini waveform for the headphone card
class _MiniWaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const heights = [0.4, 0.7, 1.0, 0.6, 0.8, 0.5, 0.9, 0.4, 0.7, 0.5];
    const barW = 3.0;
    const gap  = 2.0;
    final total = heights.length;
    final totalW = total * (barW + gap);
    final startX = (size.width - totalW) / 2;

    for (int i = 0; i < total; i++) {
      final x = startX + i * (barW + gap) + barW / 2;
      final h = heights[i] * size.height;
      final t = i / total;
      final c = Color.lerp(const Color(0xFFFF2D9B), const Color(0xFF4F6EFF), t)!;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, size.height / 2), width: barW, height: h),
          const Radius.circular(2),
        ),
        Paint()..color = c.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

/// TextStyle extension helper
extension _TextStyleLetHelper on TextStyle {
  T let<T>(T Function(TextStyle) fn) => fn(this);
}
