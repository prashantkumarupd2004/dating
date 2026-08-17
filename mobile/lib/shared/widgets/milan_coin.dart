import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Milan Coin Icon — Golden coin with "M" symbol.
/// Use this everywhere in the app instead of generic coin icons.
///
/// Usage:
///   MilanCoin(size: 20)                   // standalone icon
///   MilanCoin.withLabel(amount: 10, size: 18)  // "🪙 10" inline row
class MilanCoin extends StatelessWidget {
  final double size;
  final bool glow;

  const MilanCoin({super.key, this.size = 22, this.glow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFB800), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: glow
            ? [
                BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.45), blurRadius: size * 0.4, spreadRadius: 0),
                BoxShadow(color: const Color(0xFFFF8C00).withValues(alpha: 0.2), blurRadius: size * 0.7, spreadRadius: 0),
              ]
            : null,
        border: Border.all(color: const Color(0xFFFFF0A0).withValues(alpha: 0.6), width: 1),
      ),
      child: Center(
        child: Text(
          'M',
          style: GoogleFonts.poppins(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1,
            shadows: [Shadow(color: Colors.brown.shade700.withValues(alpha: 0.5), blurRadius: 2)],
          ),
        ),
      ),
    );
  }

  /// Inline row: [CoinIcon] [amount]
  static Widget withLabel({
    required dynamic amount,
    double size = 18,
    TextStyle? textStyle,
    Color textColor = const Color(0xFFFFD700),
    double spacing = 4,
    bool glow = false,
  }) {
    final label = amount is double
        ? amount.toInt().toString()
        : amount.toString();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MilanCoin(size: size, glow: glow),
        SizedBox(width: spacing),
        Text(
          label,
          style: textStyle ??
              GoogleFonts.poppins(
                fontSize: size * 0.72,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
        ),
      ],
    );
  }
}
