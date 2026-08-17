import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/avatar_utils.dart';

/// Premium avatar widget with online status indicator
class PremiumAvatar extends StatelessWidget {
  final String userId;
  final String name;
  final String? photoUrl;
  final bool showOnlineStatus;
  final bool isOnline;
  final bool isBusy;
  final double size;
  final double borderWidth;
  final bool showOnlineText;

  const PremiumAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.photoUrl,
    this.showOnlineStatus = true,
    this.isOnline = false,
    this.isBusy = false,
    this.size = 70,
    this.borderWidth = 2,
    this.showOnlineText = false,
  });

  Color get _statusColor {
    if (isOnline) return const Color(0xFF4CAF50);
    if (isBusy) return const Color(0xFFFF9800);
    return const Color(0xFF9E9E9E);
  }

  String get _statusText {
    if (isOnline) return 'Online';
    if (isBusy) return 'Busy';
    return 'Offline';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Avatar
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white,
                  width: borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: photoUrl != null && photoUrl!.isNotEmpty
                    ? Image.network(
                        photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildGradientAvatar(),
                      )
                    : _buildGradientAvatar(),
              ),
            ),

            // Online status indicator dot
            if (showOnlineStatus)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _statusColor.withValues(alpha: 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // Online status text
        if (showOnlineText && showOnlineStatus)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _statusText,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _statusColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGradientAvatar() {
    final avatarTheme = AvatarUtils.getAvatarForUser(userId);
    final initial = AvatarUtils.getInitial(name);

    return Container(
      decoration: BoxDecoration(
        gradient: avatarTheme.gradient,
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.poppins(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: avatarTheme.textColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
