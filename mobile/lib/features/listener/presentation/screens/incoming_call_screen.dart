import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

/// Full-screen professional incoming call UI shown to the listener.
class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callType;     // 'AUDIO' | 'VIDEO'
  final String? callerPhoto;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callType,
    required this.onAccept,
    required this.onDecline,
    this.callerPhoto,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _btnCtrl;

  late final Animation<double> _pulse1;
  late final Animation<double> _pulse2;
  late final Animation<double> _pulse3;
  late final Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();

    // Expanding pulse rings around avatar
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();

    _pulse1 = Tween<double>(begin: 1.0, end: 1.6).animate(
        CurvedAnimation(
            parent: _pulseCtrl,
            curve: const Interval(0.0, 0.70, curve: Curves.easeOut)));
    _pulse2 = Tween<double>(begin: 1.0, end: 1.9).animate(
        CurvedAnimation(
            parent: _pulseCtrl,
            curve: const Interval(0.15, 0.85, curve: Curves.easeOut)));
    _pulse3 = Tween<double>(begin: 1.0, end: 2.2).animate(
        CurvedAnimation(
            parent: _pulseCtrl,
            curve: const Interval(0.30, 1.00, curve: Curves.easeOut)));

    // Bouncing wave dots
    _waveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    // Accept button gentle pulse
    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _btnScale = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  bool get _isVideo => widget.callType == 'VIDEO';

  Color get _accentColor =>
      _isVideo ? const Color(0xFF3B82F6) : const Color(0xFF9B59B6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _isVideo
                ? [const Color(0xFF0D1B3E), const Color(0xFF1A237E), const Color(0xFF0D1B3E)]
                : [const Color(0xFF1A0A2E), const Color(0xFF6B21A8), const Color(0xFF1A0A2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),

              // ── Call type badge ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                    color: Colors.white, size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ),

              const SizedBox(height: 48),

              // ── Animated pulse + avatar ──
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) {
                  final opacity = (1 - _pulseCtrl.value);
                  return Stack(alignment: Alignment.center, children: [
                    // Outermost ring
                    Transform.scale(
                      scale: _pulse3.value,
                      child: _PulseRing(color: _accentColor, alpha: opacity * 0.07),
                    ),
                    Transform.scale(
                      scale: _pulse2.value,
                      child: _PulseRing(color: _accentColor, alpha: opacity * 0.12),
                    ),
                    Transform.scale(
                      scale: _pulse1.value,
                      child: _PulseRing(color: _accentColor, alpha: opacity * 0.18),
                    ),
                    child!,
                  ]);
                },
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isVideo
                        ? const LinearGradient(
                            colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)])
                        : AppColors.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: widget.callerPhoto != null
                      ? ClipOval(
                          child: Image.network(
                            widget.callerPhoto!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultAvatar(),
                          ),
                        )
                      : _defaultAvatar(),
                ),
              ),

              const SizedBox(height: 32),

              // ── Caller name ──
              Text(
                widget.callerName,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [const Shadow(color: Colors.black38, blurRadius: 8)],
                ),
              ),

              const SizedBox(height: 12),

              // ── Animated bouncing dots ──
              AnimatedBuilder(
                animation: _waveCtrl,
                builder: (_, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i * 0.33;
                    final t = (_waveCtrl.value - delay).clamp(0.0, 1.0);
                    final y = -7.0 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                    return Transform.translate(
                      offset: Offset(0, y),
                      child: Container(
                        width: 7, height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'is calling you…',
                style: GoogleFonts.poppins(fontSize: 15, color: Colors.white54),
              ),

              const Spacer(),

              Text(
                'Tap to respond',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white30),
              ),
              const SizedBox(height: 20),

              // ── Accept / Decline buttons ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 36),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline
                    _CallActionButton(
                      icon: Icons.call_end_rounded,
                      label: 'Decline',
                      gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
                      shadowColor: const Color(0xFFEF4444),
                      onTap: widget.onDecline,
                    ),

                    const SizedBox(width: 50),

                    // Accept — bouncing
                    ScaleTransition(
                      scale: _btnScale,
                      child: _CallActionButton(
                        icon: _isVideo
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        label: 'Accept',
                        gradient: const LinearGradient(
                            colors: [Color(0xFF16A34A), Color(0xFF22C55E)]),
                        shadowColor: const Color(0xFF22C55E),
                        onTap: widget.onAccept,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultAvatar() => Icon(
        Icons.person_rounded,
        size: 60,
        color: Colors.white.withValues(alpha: 0.9),
      );
}

/// Single translucent ring used for the pulse effect.
class _PulseRing extends StatelessWidget {
  final Color color;
  final double alpha;
  const _PulseRing({required this.color, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: alpha.clamp(0.0, 1.0)),
      ),
    );
  }
}

/// Reusable round call action button (Accept / Decline).
class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final Color shadowColor;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: gradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: shadowColor.withValues(alpha: 0.55),
                  blurRadius: 24,
                  spreadRadius: 2),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }
}
