import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';

/// Shown to a listener after submitting their application.
/// Polls the listener status and auto-navigates when APPROVED.
class ListenerUnderReviewScreen extends StatefulWidget {
  const ListenerUnderReviewScreen({super.key});

  @override
  State<ListenerUnderReviewScreen> createState() =>
      _ListenerUnderReviewScreenState();
}

class _ListenerUnderReviewScreenState extends State<ListenerUnderReviewScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _dotCtrl;
  late final Animation<double> _pulse;
  Timer? _pollTimer;
  String _status = 'PENDING';

  static const _steps = [
    _ReviewStep(
      icon: Icons.upload_rounded,
      title: 'Application Submitted',
      subtitle: 'Your profile has been received',
      done: true,
    ),
    _ReviewStep(
      icon: Icons.manage_search_rounded,
      title: 'Under Review',
      subtitle: 'Our team is reviewing your profile',
      done: false,
    ),
    _ReviewStep(
      icon: Icons.verified_rounded,
      title: 'Approval Decision',
      subtitle: 'You\'ll be notified via push notification',
      done: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Poll status every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkStatus());
    _checkStatus();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final resp = await api.get(ApiEndpoints.listenerMe);
      if (resp.statusCode == 200 && resp.data['data'] != null) {
        final st = resp.data['data']['status'] as String? ?? 'PENDING';
        if (mounted) setState(() => _status = st);
        if (st == 'APPROVED' && mounted) {
          _pollTimer?.cancel();
          _showApprovedDialog();
        }
      }
    } catch (_) {}
  }

  void _showApprovedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.pinkPurpleGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.4), blurRadius: 20)],
            ),
            child: const Icon(Icons.verified_rounded, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text('🎉 Profile Approved!',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Your Listener profile has been approved. You can now start accepting calls and earning money!',
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              context.go('/listener/dashboard');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.pinkPurpleGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.4),
                    blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Center(
                child: Text('Start Earning 🚀',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              const SizedBox(height: 20),
              Center(child: const AppLogo(fontSize: 24)),
              const Spacer(),

              // Main status card
              _buildStatusCard(),

              const SizedBox(height: 28),

              // Timeline steps
              _buildTimeline(),

              const Spacer(),

              // Bottom note + go home
              _buildBottomSection(),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: AppColors.bannerGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.3),
              blurRadius: 28, offset: const Offset(0, 12))],
        ),
        child: Column(children: [
          // Animated review icon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.manage_search_rounded,
                size: 42, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Text('Application Under Review',
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: Colors.white),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Your Listener profile has been submitted successfully and is currently under review by our team.',
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.white70, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Animated dots
          AnimatedBuilder(
            animation: _dotCtrl,
            builder: (_, __) {
              return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("Reviewing", style: GoogleFonts.poppins(
                    color: Colors.white70, fontSize: 13,
                    fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                ...List.generate(3, (i) {
                  final delay = i * 0.33;
                  final anim = ((_dotCtrl.value - delay) % 1.0 + 1.0) % 1.0;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(
                          alpha: anim < 0.5 ? 0.4 + anim : 0.4 + (1 - anim)),
                    ),
                  );
                }),
              ]);
            },
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.notifications_rounded,
                  color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text("You'll be notified when approved",
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: List.generate(_steps.length, (i) {
        final step = _steps[i];
        final isCurrent = i == 1;
        return Column(children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: step.done || isCurrent
                    ? AppColors.pinkPurpleGradient
                    : null,
                color: step.done || isCurrent ? null : AppColors.divider,
                shape: BoxShape.circle,
              ),
              child: Icon(step.icon,
                  size: 18,
                  color: step.done || isCurrent
                      ? Colors.white
                      : AppColors.textHint),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 13,
                        color: step.done || isCurrent
                            ? AppColors.textPrimary
                            : AppColors.textHint)),
                Text(step.subtitle,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: AppColors.textHint)),
              ],
            )),
            if (step.done)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 18)
            else if (isCurrent)
              SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.pink)),
          ]),
          if (i < _steps.length - 1)
            Container(
              margin: const EdgeInsets.only(left: 18, top: 4, bottom: 4),
              height: 20, width: 2,
              color: AppColors.divider,
            ),
        ]);
      })),
    );
  }

  Widget _buildBottomSection() {
    return Column(children: [
      if (_status == 'REJECTED') ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your application was not approved. You can resubmit from your profile.',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.error),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => context.go('/listener/register'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: AppColors.pinkPurpleGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text('Resubmit Application',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      TextButton(
        onPressed: () => context.go('/home'),
        child: Text('Go to Home →',
            style: GoogleFonts.poppins(
                color: AppColors.textSecondary, fontSize: 13)),
      ),
    ]);
  }
}

class _ReviewStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  const _ReviewStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
  });
}
