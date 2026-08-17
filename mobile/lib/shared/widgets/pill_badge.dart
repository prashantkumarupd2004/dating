import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PillBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final bool gradient;

  const PillBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: TextStyle(
        color: textColor ?? Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: gradient ? null : (color ?? AppColors.badgeRed),
        gradient: gradient ? AppColors.accentGradient : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
