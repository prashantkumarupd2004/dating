import 'dart:async';
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

class VideoCallScreen extends StatefulWidget {
  final Map<String, dynamic> extra;
  const VideoCallScreen({super.key, required this.extra});
  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> with WidgetsBindingObserver {
  RtcEngine? _engine;
  String? _callId;
  String _channelId = '';       // set once in _joinAgora — used by remote VideoView
  bool _inCall = false;
  bool _muted = false;
  bool _cameraOff = false;      // camera ON by default for video calls
  bool _loading = true;
  String? _error;
  int _seconds = 0;
  Timer? _timer;
  Timer? _connectionTimeout;
  int? _remoteUid;
  bool _ended = false;
  bool _navigatedAway = false; // prevent double pop

  // Buffer for call:ended events that arrive before we receive our callId from the
  // initiateCall API response. Prevents the "stuck on Connecting" bug when the
  // listener declines very quickly (before the API response arrives).
  final List<Map<String, dynamic>> _pendingEndEvents = [];

  // ── Method channel for native foreground service ──────────────────────────
  static const _platform = MethodChannel('com.milan.datingapp/call_foreground');

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addObserver(this);
    socketService.on('call:ended', _handleCallEnded);
    _startCall();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Keep the call active when backgrounded/resumed — do NOT call leaveChannel
    // The foreground service will keep the process alive
    if (state == AppLifecycleState.resumed) {
      // Ensure audio/video are not muted when returning to foreground
      if (_engine != null && _inCall) {
        _engine?.muteLocalAudioStream(_muted);
        _engine?.muteLocalVideoStream(_cameraOff);
      }
    }
  }

  /// Safely convert any JSON numeric value (int, double, String) to int.
  static int _safeUid(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _startCall() async {
    final statuses = await [Permission.microphone, Permission.camera].request();
    if (statuses[Permission.microphone] != PermissionStatus.granted ||
        statuses[Permission.camera] != PermissionStatus.granted) {
      if (!mounted) return;
      setState(() { _error = 'Camera and microphone permissions are required'; _loading = false; });
      return;
    }
    try {
      // ── RESTORATION PATH (BUG 3 FIX) ─────────────────────────────────────
      if (widget.extra['restored'] == true) {
        debugPrint('[CALL_RESTORE] Video restored from notification — skipping initiateCall API');
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

      // ── LISTENER PATH ────────────────────────────────────────────────────
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

      // ── USER / CALLER PATH ─────────────────────────────────────────────
      final resp = await api.post(ApiEndpoints.initiateCall, data: {
        'listenerId': widget.extra['listenerId'],
        'callType': 'VIDEO',
      });
      final data = resp.data['data'] as Map<String, dynamic>? ?? {};
      final channelId  = data['channelId']  as String?;
      final agoraToken = data['agoraToken'] as String?;
      final agoraAppId = data['agoraAppId'] as String?;
      _callId = data['callId'] as String? ?? '';
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
      setState(() { _error = 'Failed to start call'; _loading = false; });
    }
  }

  Future<void> _joinAgora(String channel, String token, String appId, int uid) async {
    _channelId = channel;   // ← store here so AgoraVideoView remote can use it
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));
    await _engine!.enableVideo();
    await _engine!.startPreview();
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (_, __) async {
        if (mounted) setState(() { _loading = false; });
        // ── Persist call state so it survives process death ────────────────
        final mode = widget.extra['mode'] as String? ?? 'user';
        if (_callId != null && _callId!.isNotEmpty) {
          await CallStateStore.instance.save(
            callId:       _callId!,
            channelId:    channel,
            agoraToken:   token,
            agoraAppId:   appId,
            uid:          uid,
            callType:     'VIDEO',
            mode:         mode,
            listenerName: widget.extra['listenerName'] as String? ?? 'Call',
          );
          debugPrint('[CALL_CONNECTED] VIDEO callId=$_callId mode=$mode');
          final heartbeatRole = mode == 'listener' ? 'listener' : 'user';
          CallHeartbeatService.instance.start(callId: _callId!, role: heartbeatRole);
          debugPrint('[CALL_HEARTBEAT] Started: callId=$_callId role=$heartbeatRole');
        }
        // Start foreground service to keep app alive in background
        try {
          final callerName = widget.extra['listenerName'] as String? ?? 'Call';
          await _platform.invokeMethod('startCallForeground', {
            'callerName': callerName,
            'callType': 'video',
          });
          debugPrint('[SERVICE_START] Video call foreground service started');
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
      onUserJoined: (_, uid, __) {
        if (!mounted) return;
        _connectionTimeout?.cancel();
        RingtoneService.stop(); // listener picked up — stop ringback
        setState(() { _remoteUid = uid; _inCall = true; });
        _startTimer();
      },
      onUserOffline: (_, __, ___) { if (!mounted) return; setState(() => _remoteUid = null); _endCall(remote: true); },
    ));
    await _engine!.joinChannel(token: token, channelId: channel, uid: uid, options: const ChannelMediaOptions(
      channelProfile: ChannelProfileType.channelProfileCommunication,
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      publishCameraTrack: true,
      publishMicrophoneTrack: true,
    ));
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() { _seconds++; }); });
  }

  Future<void> _endCall({bool remote = false}) async {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    _connectionTimeout?.cancel();
    RingtoneService.stop(); // stop ringback if listener never answered
    CallHeartbeatService.instance.stop();

    // Stop foreground service
    try {
      await _platform.invokeMethod('stopCallForeground');
    } catch (_) {
      // Ignore — service may already be stopped
    }

    final engine = _engine;
    _engine = null;

    // Timeout so Agora SDK never hangs the UI
    try {
      await (engine?.leaveChannel() ?? Future.value()).timeout(const Duration(seconds: 3));
      await (engine?.release() ?? Future.value()).timeout(const Duration(seconds: 3));
    } catch (_) {}

    if (_callId != null) {
      try {
        await api.post(ApiEndpoints.endCall(_callId!), data: {'endedBy': remote ? 'LISTENER' : 'USER'});
        walletProvider.fetchBalance(force: true);
      } catch (_) {}
    }
    await CallStateStore.instance.clear();
    debugPrint('[ACTIVE_CALL_CLEARED] video _endCall complete');
    WakelockPlus.disable();
    await _navigateAfterCall();
  }

  /// Processes buffered call:ended events once _callId is known.
  /// Returns true if a matching event was found and handled (skip _joinAgora).
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
    CallHeartbeatService.instance.stop();
    final engine = _engine;
    _engine = null;
    Future(() async {
      try {
        await engine?.leaveChannel().timeout(const Duration(seconds: 3));
        await engine?.release().timeout(const Duration(seconds: 3));
      } catch (_) {}
      await CallStateStore.instance.clear();
      debugPrint('[ACTIVE_CALL_CLEARED] video _handleCallEnded complete');
    });
    WakelockPlus.disable();
    if (!mounted || _navigatedAway) return;
    final reason = data['reason'] as String?;
    final message = reason == 'missed' ? 'No answer'
      : reason == 'rejected'          ? 'Call declined'
      : reason == 'listener_timeout'  ? 'Listener disconnected'
      : reason == 'caller_timeout'    ? 'You were disconnected'
      : 'Call ended';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Future(() => _navigateAfterCall());
  }

  /// Shows "End call?" confirmation dialog.
  /// Returns true if the user confirmed ending the call.
  Future<bool?> _showEndCallConfirmation() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.call_end_rounded, color: CallColors.error, size: 22),
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
              backgroundColor: CallColors.error,
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
            border: Border.all(color: Colors.white24, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.call_end_rounded, color: CallColors.error, size: 36),
              const SizedBox(height: 12),
              const Text(
                'How was your experience?',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Rate your listener',
                style: TextStyle(fontSize: 13, color: Colors.white54),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Skip', style: TextStyle(fontSize: 14)),
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
                        backgroundColor: CallColors.primary,
                        disabledBackgroundColor: Colors.white12,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Submit',
                        style: TextStyle(
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

  String get _duration { final m = _seconds ~/ 60; final s = _seconds % 60; return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'; }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    socketService.off('call:ended', _handleCallEnded);
    _timer?.cancel();
    _connectionTimeout?.cancel();
    if (!_ended) {
      // Safety net: dispose without _endCall (e.g. unexpected navigation)
      debugPrint('[CALL_END] video dispose() without _endCall — cleaning up');
      CallHeartbeatService.instance.stop();
      _platform.invokeMethod('stopCallForeground').catchError((_) {});
      _engine?.leaveChannel().catchError((_) {});
      _engine?.release().catchError((_) {});
      CallStateStore.instance.clear();
    }
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) { return const Scaffold(backgroundColor: CallColors.background, body: Center(child: CircularProgressIndicator(color: CallColors.primary))); }
    if (_error != null) {
      return Scaffold(backgroundColor: CallColors.background, body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: CallColors.error, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: CallColors.textPrimary)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => context.pop(), style: ElevatedButton.styleFrom(backgroundColor: CallColors.primary), child: const Text('Go Back')),
      ])));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Show confirmation — back press should NOT end the call silently.
        final confirmed = await _showEndCallConfirmation();
        if (confirmed == true) _endCall();
      },
      child: Scaffold(
      backgroundColor: CallColors.background,
      body: Stack(children: [
        // Remote video full screen
        if (_remoteUid != null)
          AgoraVideoView(controller: VideoViewController.remote(
            rtcEngine: _engine!,
            canvas: VideoCanvas(uid: _remoteUid!),
            connection: RtcConnection(channelId: _channelId),
          ))
        else
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 56),
            const SizedBox(height: 12),
            Text(_inCall ? 'Waiting for video...' : 'Connecting...', style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ])),
        // Local preview (PiP) — positioned below safe area + secure banner
        Positioned(
          top: 100, right: 16,
          child: Container(
            width: 100, height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: _cameraOff
                  ? Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 28),
                      ),
                    )
                  : AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
            ),
          ),
        ),
        // Top secure banner
        Positioned(top: 0, left: 0, right: 0, child: SafeArea(
          child: Container(
            color: CallColors.secureBanner.withValues(alpha: 0.85),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lock_outline, color: Colors.white, size: 13),
              SizedBox(width: 5),
              Text('Your call is secure', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
            ]),
          ),
        )),
        // Timer overlay
        if (_inCall) Positioned(top: 52, left: 0, right: 0, child: SafeArea(
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 13),
              const SizedBox(width: 5),
              Text(_duration, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          )),
        )),
        // ── Controls bar — wrapped in SafeArea so buttons sit above the
        //    system navigation bar on all Android device types.
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _btn(
                    _muted ? Icons.mic_off : Icons.mic, 'Mute', _muted,
                    () { setState(() { _muted = !_muted; _engine?.muteLocalAudioStream(_muted); }); },
                  ),
                  _endBtn(),
                  _btn(
                    Icons.flip_camera_ios, 'Flip', false,
                    () => _engine?.switchCamera(),
                  ),
                  _btn(
                    _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                    'Camera', _cameraOff,
                    () {
                      setState(() { _cameraOff = !_cameraOff; });
                      // enableLocalVideo(false) turns the camera hardware OFF (not just mutes the stream).
                      // enableLocalVideo(true) restores it, including the local preview.
                      _engine?.enableLocalVideo(!_cameraOff);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
      ),
    );
  }

  Widget _btn(IconData icon, String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 50, height: 50, decoration: BoxDecoration(color: active ? CallColors.primary : Colors.white24, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 22)),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
    ]),
  );

  Widget _endBtn() => GestureDetector(
    onTap: () => _endCall(),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(color: CallColors.error, shape: BoxShape.circle, boxShadow: [BoxShadow(color: CallColors.error.withValues(alpha: 0.4), blurRadius: 18)]), child: const Icon(Icons.call_end, color: Colors.white, size: 28)),
      const SizedBox(height: 5),
      const Text('End', style: TextStyle(color: Colors.white54, fontSize: 10)),
    ]),
  );
}
