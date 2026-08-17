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


class _ListenerDashboardScreenState extends State<ListenerDashboardScreen> {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  bool _isOnline = false;
  String? _listenerId;
  String? _incomingCallId;
  bool _dialogShowing = false;
  DateTime? _lastRefresh; // Track last refresh time

  @override
  void initState() {
    super.initState();
    _load();
    socketService.on('call:incoming', _handleIncomingCall);
    socketService.on('call:ended', _handleCallEnded);
  }

  Future<void> _load() async {
    // Prevent rapid refresh - only allow refresh every 30 seconds
    if (_lastRefresh != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefresh!);
      if (timeSinceLastRefresh.inSeconds < 30) {
        debugPrint('⏸️ [Dashboard] Skipping refresh - last refresh was ${timeSinceLastRefresh.inSeconds}s ago');
        return;
      }
    }

    // Prevent concurrent requests
    if (_loading) {
      debugPrint('⏸️ [Dashboard] Already loading, skipping...');
      return;
    }

    setState(() => _loading = true);
    _lastRefresh = DateTime.now();

    try {
      final resp = await api.get(ApiEndpoints.earningsSummary);
      setState(() { _summary = resp.data['data']; });
    } catch (e) {
      debugPrint('Earnings API error: $e');
    }
    try {
      final resp = await api.get(ApiEndpoints.listenerMe);
      final listenerData = resp.data['data'];
      final status = listenerData['onlineStatus'] as String? ?? 'OFFLINE';
      _listenerId = listenerData['id'] as String?;
      setState(() => _isOnline = status == 'ONLINE');
      if (_isOnline && _listenerId != null) socketService.goOnline(_listenerId!);
    } catch (e) {
      debugPrint('Listener Me API error: $e');
    }
    setState(() => _loading = false);
  }

  void _handleIncomingCall(dynamic data) {
    _incomingCallId = data['callId'] as String?;
    _dialogShowing = true;
    RingtoneService.playIncoming();
    showGeneralDialog(
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
        callType: data['callType'] as String? ?? 'AUDIO',
        callerPhoto: data['callerPhoto'] as String?,
        onAccept: () => _acceptCall(data),
        onDecline: () {
          _dismissIncomingDialog();
          api.post(ApiEndpoints.rejectCall(data['callId']));
        },
      ),
    ).then((_) { _dialogShowing = false; });
  }

  void _dismissIncomingDialog() {
    RingtoneService.stop(); // stop ring on accept, decline, or remote cancel
    if (_dialogShowing && mounted) Navigator.pop(context);
    _dialogShowing = false;
    _incomingCallId = null;
  }

  void _handleCallEnded(dynamic data) {
    if (_dialogShowing && data['callId'] == _incomingCallId) _dismissIncomingDialog();
  }

  Future<void> _acceptCall(dynamic data) async {
    _dismissIncomingDialog();
    try {
      final resp = await api.post(ApiEndpoints.acceptCall(data['callId']));
      final call = resp.data['data'];
      if (!mounted) return;
      context.push(call['type'] == 'VIDEO' ? '/call/video' : '/call/audio', extra: {
        'mode': 'listener', 'callId': call['id'], 'channelId': call['channelId'],
        'agoraToken': call['agoraToken'], 'agoraAppId': call['agoraAppId'],
        'uid': call['listenerUid'], 'listenerName': data['callerName'] ?? 'Someone',
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not accept: ${e.toString()}'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _toggleOnline() async {
    final newStatus = _isOnline ? 'OFFLINE' : 'ONLINE';
    try {
      await api.patch(ApiEndpoints.listenerStatus, data: {'status': newStatus});
      setState(() => _isOnline = !_isOnline);
      if (newStatus == 'ONLINE') {
        if (_listenerId != null) socketService.goOnline(_listenerId!);
      } else {
        socketService.goOffline();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  void dispose() { socketService.off('call:incoming'); socketService.off('call:ended'); super.dispose(); }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return '0m';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

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
                ...recentCalls.map((call) => _recentCallCard(call)),
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

