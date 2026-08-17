import 'package:flutter/material.dart';

class AppColors {
  // ── Background ─────────────────────────────────────────────────────────────
  static const bgGradientTop    = Color(0xFFFFF0F5); // soft blush pink
  static const bgGradientBottom = Color(0xFFF3EEFF); // soft lavender

  // ── Brand / Primary ────────────────────────────────────────────────────────
  static const pink             = Color(0xFFFF4D8B);  // Connecto pink
  static const pinkDark         = Color(0xFFE0366F);
  static const purple           = Color(0xFF9B59B6);
  static const purpleDark       = Color(0xFF7D3C98);
  static const blue             = Color(0xFF4F6EFF);
  static const blueDark         = Color(0xFF3254DB);

  // Legacy aliases kept for backward compat
  static const primary          = blue;
  static const primaryDark      = blueDark;
  static const accentStart      = purple;
  static const accentEnd        = pink;

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [bgGradientTop, bgGradientBottom],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Pink → purple (chips, active elements, logo)
  static const LinearGradient pinkPurpleGradient = LinearGradient(
    colors: [Color(0xFFFF4D8B), Color(0xFF9B59B6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Blue → purple (Call Now button)
  static const LinearGradient callBtnGradient = LinearGradient(
    colors: [Color(0xFF4F6EFF), Color(0xFF9B59B6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Pink → lavender → purple (banner card)
  static const LinearGradient bannerGradient = LinearGradient(
    colors: [Color(0xFFFF6B9D), Color(0xFFBB6BD9), Color(0xFF7B6FF5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Legacy accentGradient
  static const LinearGradient accentGradient = pinkPurpleGradient;

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const surface          = Color(0xFFFFFFFF);
  static const surfaceLight     = Color(0xFFF7F7F9);
  static const card             = Color(0xFFFFFFFF);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textPrimary      = Color(0xFF1A1A2E);
  static const textSecondary    = Color(0xFF6B7280);
  static const textHint         = Color(0xFF9CA3AF);

  // ── Status ─────────────────────────────────────────────────────────────────
  static const online           = Color(0xFF2ECC71);
  static const busy             = Color(0xFFFF9800);
  static const offline          = Color(0xFF9E9E9E);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const success          = Color(0xFF2E9E4C);
  static const error            = Color(0xFFE53935);
  static const warning          = Color(0xFFFF9800);
  static const gold             = Color(0xFFFFB300);
  static const badgeRed         = Color(0xFFE5395A);

  // ── Misc ───────────────────────────────────────────────────────────────────
  static const divider          = Color(0xFFEEEEF4);
  static const shimmerBase      = Color(0xFFEEEEEE);
  static const shimmerHighlight = Color(0xFFF5F5F5);
}
