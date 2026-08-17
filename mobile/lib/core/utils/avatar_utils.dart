import 'package:flutter/material.dart';

/// Premium avatar system with 20 unique gradient combinations
/// Avatars are assigned based on user ID hash for consistency
class AvatarUtils {
  static const List<AvatarTheme> _avatars = [
    // Warm & Vibrant
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Ocean Blue
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFF4E54C8), Color(0xFF8F94FB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Purple Dream
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFF9B59B6), Color(0xFFE74C3C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Mint Fresh
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Sunset Orange
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFFFF512F), Color(0xFFF09819)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Royal Purple
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Rose Gold
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFFEB3349), Color(0xFFF45C43)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Teal Ocean
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Peachy Pink
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFFFD746C), Color(0xFFFF9068)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Electric Violet
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Emerald Green
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFF56AB2F), Color(0xFFA8E063)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Cotton Candy
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFFFBC2EB), Color(0xFFA6C1EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Color(0xFF5A5A5A),
    ),
    // Cosmic Purple
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Cherry Blossom
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFFFF758C), Color(0xFFFF7EB3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Sky Blue
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Coral Reef
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFFFF6F61), Color(0xFFFFB88C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Lavender Dreams
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFFB06AB3), Color(0xFF4568DC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Golden Hour
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFFFFD89B), Color(0xFF19547B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Berry Burst
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
    // Aqua Marine
    AvatarTheme(
      gradient: LinearGradient(
        colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Colors.white,
    ),
  ];

  /// Get avatar theme for a user based on their ID
  /// Same user ID always returns the same avatar
  static AvatarTheme getAvatarForUser(String userId) {
    final hash = userId.hashCode.abs();
    final index = hash % _avatars.length;
    return _avatars[index];
  }

  /// Get the first letter of a name, or '?' if empty
  static String getInitial(String name) {
    if (name.isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }
}

/// Avatar theme containing gradient and text color
class AvatarTheme {
  final Gradient gradient;
  final Color textColor;

  const AvatarTheme({
    required this.gradient,
    required this.textColor,
  });
}
