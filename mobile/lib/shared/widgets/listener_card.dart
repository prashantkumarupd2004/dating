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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF9B59B6).withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Premium Avatar with Online Status
            Column(
              children: [
                PremiumAvatar(
                  userId: listener.id,
                  name: listener.displayName,
                  photoUrl: listener.photoUrl,
                  showOnlineStatus: true,
                  isOnline: listener.isOnline,
                  isBusy: listener.isBusy,
                  size: 70,
                  borderWidth: 2,
                  showOnlineText: false,
                ),
                const SizedBox(height: 4),
                // Online status text below avatar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(listener.displayName,
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, size: 13, color: AppColors.blue),
                    if (listener.age != null) ...[
                      const SizedBox(width: 4),
                      Text('· ${listener.age}y',
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ]),
                  if (listener.locationDisplay.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textHint),
                      const SizedBox(width: 2),
                      Text(listener.locationDisplay,
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ],
                  if (listener.relationshipStatus != null) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.favorite_border_rounded, size: 11, color: AppColors.pink),
                      const SizedBox(width: 2),
                      Text(listener.relationshipStatus!,
                          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ],
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 13, color: AppColors.gold),
                    const SizedBox(width: 2),
                    Text(listener.rating.toStringAsFixed(1),
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(width: 10),
                    Text(priceStr,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ]),
                  if (listener.bio != null) ...[
                    const SizedBox(height: 4),
                    Text(listener.bio!,
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Call button
            GestureDetector(
              onTap: listener.isOnline
                  ? () => context.push('/call/audio', extra: {
                        'listenerId': listener.id,
                        'listenerName': listener.displayName,
                        'listenerPhoto': listener.photoUrl,
                      })
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: listener.isOnline ? AppColors.callBtnGradient : null,
                  color: listener.isOnline ? null : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: listener.isOnline
                      ? [BoxShadow(color: AppColors.blue.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                      : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.call_rounded, size: 13, color: listener.isOnline ? Colors.white : AppColors.textHint),
                  const SizedBox(width: 4),
                  Text('Call', style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: listener.isOnline ? Colors.white : AppColors.textHint,
                  )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
