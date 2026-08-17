import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

/// Milan branded logo — heart icon + "Milan" text + tagline.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.showTagline = true, this.fontSize});
  final bool showTagline;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Heart icon with pink→purple gradient
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.pinkPurpleGradient.createShader(bounds),
          child: const Icon(Icons.favorite_rounded, size: 30, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.pinkPurpleGradient.createShader(bounds),
              child: Text(
                'Milan',
                style: GoogleFonts.pacifico(
                  fontSize: fontSize ?? 22,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
            if (showTagline)
              Text(
                'Real People • Real Connections',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
