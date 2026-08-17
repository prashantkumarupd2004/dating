import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/wallet_provider.dart';
import '../../../../core/services/ringtone_service.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/theme/call_colors.dart';

class VideoCallScreen extends StatefulWidget {
  final Map<String, dynamic> extra;
  const VideoCallScreen({super.key, required this.extra});
  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RtcEngine? _engine;
  String? _callId;
  bool _inCall = false;
  bool _muted = false;
  bool _cameraOff = false;
  bool _loading = true;
  String? _error;
  int _seconds = 0;
  Timer? _timer;
  Timer? _connectionTimeout;
  int? _remoteUid;
  bool _ended = false;
  bool _navigatedAway = false; // prevent double pop

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    socketService.on('call:ended', _handleCallEnded);
    _startCall();
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
      if (widget.extra['mode'] == 'listener') {
        _callId = widget.extra['callId'] as String;
        await _joinAgora(
          widget.extra['channelId'] as String,
          widget.extra['agoraToken'] as String,
          widget.extra['agoraAppId'] as String,
          (widget.extra['uid'] as num).toInt(), // safe cast
        );
        return;
      }
      final resp = await api.post(ApiEndpoints.initiateCall, data: {
        'listenerId': widget.extra['listenerId'],
        'callType': 'VIDEO',
      });
      final data = resp.data['data'];
      _callId = data['callId'] as String;
      await _joinAgora(
        data['channelId'] as String,
        data['agoraToken'] as String,
        data['agoraAppId'] as String,
        (data['userUid'] as num).toInt(), // safe cast
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Failed to start call'; _loading = false; });
    }
  }

  Future<void> _joinAgora(String channel, String token, String appId, int uid) async {
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));
    await _engine!.enableVideo();
    await _engine!.startPreview();
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (_, __) {
        if (mounted) setState(() { _loading = false; });
        // Play ringback tone for the caller while waiting for the listener to answer.
        if (widget.extra['mode'] != 'listener') RingtoneService.playRingback();
        // Start a 60-second timeout — if no remote user joins, auto-end the call
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
    WakelockPlus.disable();
    await _navigateAfterCall();
  }

  void _handleCallEnded(dynamic data) {
    if (_ended || data['callId'] != _callId) return;
    _ended = true;
    _timer?.cancel();
    _connectionTimeout?.cancel();
    RingtoneService.stop(); // remote ended — stop ringback if still ringing
    final engine = _engine;
    _engine = null;
    Future(() async {
      try {
        await engine?.leaveChannel().timeout(const Duration(seconds: 3));
        await engine?.release().timeout(const Duration(seconds: 3));
      } catch (_) {}
    });
    WakelockPlus.disable();
    if (!mounted || _navigatedAway) return;
    final reason = data['reason'] as String?;
    final message = reason == 'missed' ? 'No answer' : reason == 'rejected' ? 'Call declined' : 'Call ended';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Future(() => _navigateAfterCall());
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
    socketService.off('call:ended', _handleCallEnded);
    _timer?.cancel();
    _connectionTimeout?.cancel();
    if (!_ended) {
      _engine?.leaveChannel().catchError((_) {});
      _engine?.release().catchError((_) {});
    }
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: CallColors.background, body: Center(child: CircularProgressIndicator(color: CallColors.primary)));
    if (_error != null) return Scaffold(backgroundColor: CallColors.background, body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: CallColors.error, size: 48),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: CallColors.textPrimary)),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: () => context.pop(), style: ElevatedButton.styleFrom(backgroundColor: CallColors.primary), child: const Text('Go Back')),
    ])));

    return Scaffold(
      backgroundColor: CallColors.background,
      body: Stack(children: [
        // Remote video full screen
        if (_remoteUid != null)
          AgoraVideoView(controller: VideoViewController.remote(
            rtcEngine: _engine!,
            canvas: VideoCanvas(uid: _remoteUid!),
            connection: RtcConnection(channelId: widget.extra['channelId'] as String? ?? ''),
          ))
        else
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 56),
            const SizedBox(height: 12),
            Text(_inCall ? 'Waiting for video...' : 'Connecting...', style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ])),
        // Local preview (PiP) — positioned below safe area + secure banner
        Positioned(top: 100, right: 16, child: Container(
          width: 100, height: 140,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24, width: 1.5)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: AgoraVideoView(controller: VideoViewController(rtcEngine: _engine!, canvas: const VideoCanvas(uid: 0))),
          ),
        )),
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
        // Controls bar at bottom
        Positioned(bottom: 0, left: 0, right: 0, child: Container(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 40),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent])),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _btn(_muted ? Icons.mic_off : Icons.mic, 'Mute', _muted, () { setState(() { _muted = !_muted; _engine?.muteLocalAudioStream(_muted); }); }),
            _endBtn(),
            _btn(Icons.flip_camera_ios, 'Flip', false, () => _engine?.switchCamera()),
            _btn(_cameraOff ? Icons.videocam_off : Icons.videocam, 'Camera', _cameraOff, () { setState(() { _cameraOff = !_cameraOff; _engine?.muteLocalVideoStream(_cameraOff); }); }),
          ]),
        )),
      ]),
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
