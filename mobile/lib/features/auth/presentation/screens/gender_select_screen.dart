import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';

class GenderSelectScreen extends StatelessWidget {
  const GenderSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const AppLogo(fontSize: 36, showTagline: true),
            const SizedBox(height: 48),
            const Text('I am a...', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('Choose how you want to use Milan', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const Spacer(),
            _GenderCard(
              emoji: '👨',
              title: 'Male',
              subtitle: 'Browse & talk to listeners',
              note: null,
              gradientColors: const [Color(0xFF3D7BFF), Color(0xFF6C63FF)],
              onTap: () => context.go('/auth/register?gender=MALE'),
            ),
            const SizedBox(height: 20),
            _GenderCard(
              emoji: '👩',
              title: 'Female',
              subtitle: 'Become a listener & earn',
              note: 'Audio Voice Verification Required',
              gradientColors: const [Color(0xFFFF4D6D), Color(0xFF7C4DFF)],
              onTap: () => context.go('/listener/voice-verify'),
            ),
            const Spacer(),
            const Text(
              'You can always change this later from your profile',
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? note;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _GenderCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.note,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: gradientColors[0].withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 20),
            ]),
            if (note != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.mic_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(note!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
