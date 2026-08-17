import 'package:flutter/material.dart';

/// Dark navy + neon color palette for the Connecto premium call screen.
class CallColors {
  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const background     = Color(0xFF07081A); // deep navy black
  static const surface        = Color(0xFF0F1035);
  static const surfaceLight   = Color(0xFF151640);
  static const card           = Color(0xFF12142E);
  static const glassCard      = Color(0x22FFFFFF); // frosted glass

  // ── Brand accents ──────────────────────────────────────────────────────────
  static const neonPink       = Color(0xFFFF2D9B);
  static const electricBlue   = Color(0xFF4F6EFF);
  static const neonPurple     = Color(0xFF9B59B6);
  static const neonGreen      = Color(0xFF39FF14);

  // ── Legacy aliases ─────────────────────────────────────────────────────────
  static const primary        = neonPink;
  static const secondary      = electricBlue;
  static const error          = Color(0xFFE53935);
  static const success        = Color(0xFF43A047);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textPrimary    = Color(0xFFFFFFFF);
  static const textSecondary  = Color(0xFFB0B0C8);
  static const textHint       = Color(0xFF6B6B8A);

  // ── Misc ───────────────────────────────────────────────────────────────────
  static const gold           = Color(0xFFFFD700);
  static const divider        = Color(0xFF2A2A4A);
  static const secureBanner   = Color(0xFF1B5E20);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient logoGradient = LinearGradient(
    colors: [electricBlue, neonPurple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient callBtnGradient = LinearGradient(
    colors: [electricBlue, neonPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient waveformGradient = LinearGradient(
    colors: [neonPink, neonPurple, electricBlue],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF07081A), Color(0xFF120828), Color(0xFF07081A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
