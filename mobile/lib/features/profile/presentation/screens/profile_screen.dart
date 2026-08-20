import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/wallet_provider.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/milan_coin.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _listenerData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await api.get(ApiEndpoints.me);
      final data = resp.data['data'];
      if (mounted) setState(() => _user = data);
      final balance = (data['wallet']?['balance'] as num?)?.toDouble() ?? 0;
      walletProvider.updateBalance(balance);
    } catch (e) {
      debugPrint('Profile load error: $e');
    }
    try {
      final lResp = await api.get(ApiEndpoints.listenerMe);
      if (lResp.statusCode == 200 && lResp.data['data'] != null) {
        if (mounted) setState(() => _listenerData = lResp.data['data']);
      } else {
        if (mounted) setState(() => _listenerData = null);
      }
    } catch (_) {
      if (mounted) setState(() => _listenerData = null);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to logout?',
            style: GoogleFonts.poppins(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8, bottom: 4),
            decoration: BoxDecoration(
              gradient: AppColors.pinkPurpleGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Logout',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final refresh = await SecureStorage.getRefreshToken();
      await api.post(ApiEndpoints.authLogout, data: {'refreshToken': refresh});
    } catch (_) {}
    await sessionManager.clearSession();
    walletProvider.reset();
    if (mounted) context.go('/auth/login');
  }

  String get _listenerStatus => _listenerData?['status'] as String? ?? '';
  bool get _isApproved => _listenerStatus == 'APPROVED';
  bool get _hasApplied => _listenerData != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  child: Column(children: [
                    _buildProfileCard(),
                    const SizedBox(height: 20),
                    _buildWalletSection(),
                    const SizedBox(height: 14),
                    if (!_hasApplied || !_isApproved) ...[
                      _buildListenerSection(),
                      const SizedBox(height: 14),
                    ],
                    _buildSupportSection(),
                    const SizedBox(height: 14),
                    _buildLogoutBtn(),
                  ]),
                ),
              ),
      ),
    );
  }

  // ── Profile Header Card ───────────────────────────────────────────────────

  Widget _buildProfileCard() {
    final name = _user?['name'] as String? ?? 'User';
    final phone = (_user?['phone'] ?? _user?['email'] ?? '') as String;
    final photoUrl = _user?['profile']?['photoUrl'] as String?;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.bannerGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.pink.withValues(alpha: 0.25),
              blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(children: [
        // Decorative circle
        Positioned(top: -20, right: -20,
          child: Container(width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06)))),

        Column(children: [
          Row(children: [
            // Avatar
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(initials,
                        style: GoogleFonts.poppins(
                            fontSize: 28, fontWeight: FontWeight.w800,
                            color: Colors.white))
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (phone.isNotEmpty)
                  Text(phone,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.white70)),
                if (_hasApplied && !_isApproved) ...[
                  const SizedBox(height: 4),
                  _listenerBadge(),
                ],
              ],
            )),
          ]),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),

          // Balance row
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const MilanCoin(size: 28, glow: true),
            const SizedBox(width: 10),
            ListenableBuilder(
              listenable: walletProvider,
              builder: (_, __) => Text(
                walletProvider.balance.toInt().toString(),
                style: GoogleFonts.poppins(
                    fontSize: 32, fontWeight: FontWeight.w800,
                    color: Colors.white, height: 1),
              ),
            ),
            const SizedBox(width: 8),
            Text('Coins',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.white70,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/recharge'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add, size: 14, color: AppColors.pink),
                  const SizedBox(width: 4),
                  Text('Add',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, fontSize: 13,
                          color: AppColors.textPrimary)),
                ]),
              ),
            ),
          ]),
        ]),
      ]),
    );
  }

  // ── Wallet Section ─────────────────────────────────────────────────────────

  Widget _buildWalletSection() {
    return _SectionCard(
      title: 'Wallet',
      items: [
        _SectionItem(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Wallet & Transactions',
          color: AppColors.primary,
          onTap: () => context.push('/wallet'),
        ),
        _SectionItem(
          icon: Icons.add_circle_rounded,
          label: 'Buy Coins',
          color: AppColors.gold,
          onTap: () => context.push('/recharge'),
        ),
      ],
    );
  }

  // ── Listener Section ───────────────────────────────────────────────────────

  Widget _buildListenerSection() {
    if (!_hasApplied) {
      return _SectionCard(
        title: 'Earn with Connecto',
        items: [
          _SectionItem(
            icon: Icons.headset_mic_rounded,
            label: 'Become a Listener',
            subtitle: 'Earn money by talking to users',
            color: AppColors.purple,
            onTap: () => context.push('/listener/register'),
          ),
        ],
      );
    }
    if (!_isApproved) {
      return _SectionCard(
        title: 'Listener Application',
        items: [
          _SectionItem(
            icon: Icons.hourglass_top_rounded,
            label: 'Application Status',
            subtitle: _listenerStatus,
            color: AppColors.busy,
            onTap: () {},
            showArrow: false,
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  // ── Support & Legal Section ────────────────────────────────────────────────

  Widget _buildSupportSection() {
    return _SectionCard(
      title: 'Support & Legal',
      items: [
        _SectionItem(
          icon: Icons.settings_rounded,
          label: 'Account Settings',
          color: AppColors.textSecondary,
          onTap: () => context.push('/settings/account'),
        ),
        _SectionItem(
          icon: Icons.help_rounded,
          label: 'Help & Support',
          subtitle: 'Raise a ticket or view past tickets',
          color: AppColors.blue,
          onTap: () => context.push('/user/help-support'),
        ),
        _SectionItem(
          icon: Icons.description_rounded,
          label: 'Terms & Conditions',
          color: AppColors.purple,
          onTap: () => context.push('/user/terms'),
        ),
      ],
    );
  }

  // ── Logout Button ──────────────────────────────────────────────────────────

  Widget _buildLogoutBtn() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.08),
              blurRadius: 12, offset: const Offset(0, 4))],
          border: Border.all(
              color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Text('Logout',
              style: GoogleFonts.poppins(
                  color: AppColors.error, fontWeight: FontWeight.w600,
                  fontSize: 15)),
        ]),
      ),
    );
  }

  Widget _listenerBadge() {
    final colors = {
      'APPROVED': AppColors.success,
      'PENDING': AppColors.busy,
      'REJECTED': AppColors.error,
      'SUSPENDED': AppColors.error,
    };
    final labels = {
      'APPROVED': 'Listener Active',
      'PENDING': 'Under Review',
      'REJECTED': 'Application Rejected',
      'SUSPENDED': 'Account Suspended',
    };
    final _ = colors[_listenerStatus] ?? AppColors.textHint; // kept for future use
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        labels[_listenerStatus] ?? _listenerStatus,
        style: GoogleFonts.poppins(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Reusable Section Card ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<_SectionItem> items;
  const _SectionCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.textHint,
                letterSpacing: 0.5)),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(children: List.generate(items.length, (i) {
          return Column(children: [
            items[i]._build(context),
            if (i < items.length - 1)
              const Divider(height: 0, indent: 60, color: AppColors.divider),
          ]);
        })),
      ),
    ]);
  }
}

class _SectionItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool showArrow;

  const _SectionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.showArrow = true,
  });

  Widget _build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      title: Text(label,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 14,
              color: AppColors.textPrimary)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: AppColors.textHint))
          : null,
      trailing: showArrow
          ? const Icon(Icons.chevron_right_rounded,
              color: AppColors.textHint, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
