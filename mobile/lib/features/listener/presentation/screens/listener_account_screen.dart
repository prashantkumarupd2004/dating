import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/services/locale_service.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/providers/wallet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/call_state_store.dart';

class ListenerAccountScreen extends StatefulWidget {
  const ListenerAccountScreen({super.key});
  @override
  State<ListenerAccountScreen> createState() => _ListenerAccountScreenState();
}

class _ListenerAccountScreenState extends State<ListenerAccountScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    localeService.locale.addListener(_onLocaleChange);
  }

  @override
  void dispose() {
    localeService.locale.removeListener(_onLocaleChange);
    super.dispose();
  }

  void _onLocaleChange() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final resp = await api.get(ApiEndpoints.listenerMe);
      if (mounted) {
        setState(() {
          _profile = resp.data['data'] as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final l = AppLocalizations.current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.confirmLogout),
        content: Text(l.logoutMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l.logout, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final refresh = await SecureStorage.getRefreshToken();
      await api.post(ApiEndpoints.authLogout, data: {'refreshToken': refresh});
    } catch (_) {}

    await CallStateStore.instance.clear();
    await sessionManager.clearSession();
    walletProvider.reset();

    if (mounted) context.go('/auth/login');
  }

  // ─── Delete Account ─────────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final l = AppLocalizations.current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.confirmDelete),
        content: Text(l.deleteMessage, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l.deleteForever, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await api.delete(ApiEndpoints.me);
      await CallStateStore.instance.clear();
      await sessionManager.clearSession();
      walletProvider.reset();
      if (mounted) context.go('/auth/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── Language Picker ────────────────────────────────────────────────────────
  void _showLanguagePicker() {
    final l = AppLocalizations.current;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(l.selectLanguage, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            _langTile(ctx, 'en', l.english, '🇬🇧'),
            _langTile(ctx, 'hi', l.hindi, '🇮🇳'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _langTile(BuildContext ctx, String code, String label, String flag) {
    final selected = localeService.currentCode == code;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 22)),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w400, color: selected ? AppColors.primary : AppColors.textPrimary)),
      trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
      onTap: () async {
        await localeService.setLocale(code);
        if (ctx.mounted) Navigator.pop(ctx);
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.current;

    // Listener profile data
    final lProfile  = _profile?['profile'] as Map<String, dynamic>?;
    final name      = lProfile?['displayName'] as String? ?? 'Listener';
    final photoUrl  = lProfile?['photoUrl'] as String?;
    final status    = _profile?['status'] as String? ?? '';
    final rating    = (_profile?['rating'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // ── Header ─────────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.callBtnGradient,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                    ),
                    padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 24, 24, 28),
                    child: Column(children: [
                      // Avatar
                      Stack(children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            color: Colors.white24,
                          ),
                          child: ClipOval(
                            child: photoUrl != null
                                ? Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarFallback(name))
                                : _avatarFallback(name),
                          ),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.headset_mic, size: 12, color: Colors.white),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 16),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 12),
                        _statusChip(status),
                      ]),
                    ]),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── Main Menu ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _menuSection([
                    _menuTile(Icons.account_balance_wallet_outlined, l.earnings, AppColors.success,       () => context.push('/listener/payout')),
                    _divider(),
                    _menuTile(Icons.call_outlined,                    l.callHistory, AppColors.primary,   () => context.go('/listener/dashboard', extra: {'tab': 1})),
                    _divider(),
                    _menuTile(Icons.help_outline,                     l.helpSupport, AppColors.accentStart, () => context.push('/listener/help-support')),
                  ]),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── Preferences ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _menuSection([
                    _menuTile(Icons.language_outlined, l.language, AppColors.purple, _showLanguagePicker),
                    _divider(),
                    _menuTile(Icons.description_outlined,            l.terms,   AppColors.textSecondary, () => context.push('/listener/terms')),
                    _divider(),
                    _menuTile(Icons.privacy_tip_outlined,            l.privacy, AppColors.textSecondary, () => context.push('/listener/privacy')),
                  ]),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── Danger Zone ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _menuSection([
                    _menuTile(Icons.logout, l.logout, AppColors.warning, _logout),
                    _divider(),
                    _menuTile(Icons.delete_forever_outlined, l.deleteAccount, AppColors.error, _deleteAccount),
                  ]),
                ),

                // ── Version ────────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 40),
                    child: Center(
                      child: Text('${l.version} 1.0.2', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _avatarFallback(String name) => Container(
        color: AppColors.accentStart.withValues(alpha: 0.2),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'L',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );

  Widget _statusChip(String status) {
    final colors = {'APPROVED': AppColors.success, 'PENDING': AppColors.busy, 'SUSPENDED': AppColors.error, 'REJECTED': AppColors.error};
    final color = colors[status] ?? Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: color == AppColors.success ? Colors.white : color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _menuSection(List<Widget> children) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(children: children),
      );

  Widget _divider() => const Divider(height: 0, indent: 54, color: Color(0xFFEEEEF4));

  Widget _menuTile(IconData icon, String title, Color color, VoidCallback onTap) => ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(title, style: TextStyle(color: color == AppColors.error ? AppColors.error : AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
        onTap: onTap,
      );
}
