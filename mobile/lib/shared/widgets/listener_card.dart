import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../models/models.dart';
import 'premium_avatar.dart';

class ListenerCard extends StatelessWidget {
  final ListenerModel listener;
  final VoidCallback? onRefresh;
  const ListenerCard({super.key, required this.listener, this.onRefresh});

  Color get _statusColor {
    if (listener.isOnline) return AppColors.online;
    if (listener.isBusy) return AppColors.busy;
    return AppColors.offline;
  }

  String get _statusText {
    if (listener.isOnline) return 'Online';
    if (listener.isBusy) return 'Busy';
    return 'Offline';
  }

  @override
  Widget build(BuildContext context) {
    final price = listener.pricePerMin;
    final priceStr = price == price.truncateToDouble()
        ? '₹${price.toInt()}/min'
        : '₹${price.toStringAsFixed(1)}/min';

    final canAudio = listener.isOnline && listener.isAudioEnabled;
    final canVideo = listener.isOnline && listener.isVideoEnabled;

    return GestureDetector(
      onTap: () => context.push('/home/listener/${listener.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9B59B6).withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Avatar + status badge ──────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PremiumAvatar(
                    userId: listener.id,
                    name: listener.displayName,
                    photoUrl: listener.photoUrl,
                    showOnlineStatus: true,
                    isOnline: listener.isOnline,
                    isBusy: listener.isBusy,
                    size: 66,
                    borderWidth: 2,
                    showOnlineText: false,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _statusText,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // ── Info + call buttons ───────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name + verified + age
                    Row(children: [
                      Flexible(
                        child: Text(
                          listener.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, size: 13, color: AppColors.blue),
                      if (listener.age != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '· ${listener.age}y',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ]),

                    // Location
                    if (listener.locationDisplay.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textHint),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            listener.locationDisplay,
                            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    ],

                    // Rating + price
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 13, color: AppColors.gold),
                      const SizedBox(width: 2),
                      Text(
                        listener.rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        priceStr,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ]),

                    // Bio
                    if (listener.bio != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        listener.bio!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // ── Call buttons row ─────────────────────────────────
                    Row(
                      children: [
                        // Voice button
                        _CallButton(
                          icon: Icons.mic_rounded,
                          label: 'Voice',
                          enabled: canAudio,
                          color: AppColors.primary,
                          disabledReason: !listener.isOnline
                              ? null // just show disabled without tooltip when offline
                              : !listener.isAudioEnabled
                                  ? 'Audio N/A'
                                  : null,
                          onTap: canAudio
                              ? () => context.push('/call/audio', extra: {
                                    'listenerId': listener.id,
                                    'listenerName': listener.displayName,
                                    'listenerPhoto': listener.photoUrl,
                                  })
                              : null,
                        ),
                        const SizedBox(width: 8),
                        // Video button
                        _CallButton(
                          icon: Icons.videocam_rounded,
                          label: 'Video',
                          enabled: canVideo,
                          color: AppColors.blue,
                          disabledReason: !listener.isOnline
                              ? null
                              : !listener.isVideoEnabled
                                  ? 'Video N/A'
                                  : null,
                          onTap: canVideo
                              ? () => context.push('/call/video', extra: {
                                    'listenerId': listener.id,
                                    'listenerName': listener.displayName,
                                    'listenerPhoto': listener.photoUrl,
                                  })
                              : null,
                        ),
                      ],
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
}

// ── Small call button widget ──────────────────────────────────────────────────

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final Color color;
  final String? disabledReason;
  final VoidCallback? onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.color,
    this.disabledReason,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            icon,
            size: 13,
            color: enabled ? Colors.white : AppColors.textHint,
          ),
          const SizedBox(width: 4),
          Text(
            disabledReason ?? label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: enabled ? Colors.white : AppColors.textHint,
            ),
          ),
        ]),
      ),
    );
  }
}
