import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _notifCalls = true;
  bool _notifBalance = true;
  bool _notifPromo = true;

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await api.delete(ApiEndpoints.me);
      await sessionManager.clearSession();
      if (mounted) context.go('/auth/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      final refresh = await SecureStorage.getRefreshToken();
      await api.post(ApiEndpoints.authLogout, data: {'refreshToken': refresh});
    } catch (_) {}

    // Clear session using session manager
    await sessionManager.clearSession();

    if (mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: SingleChildScrollView(
        child: Column(children: [
          _section('Notifications', [
            _toggle('Incoming Calls', 'Get notified when a call comes in', _notifCalls, (v) => setState(() => _notifCalls = v)),
            _toggle('Low Balance Alerts', 'Warn when coins are running low', _notifBalance, (v) => setState(() => _notifBalance = v)),
            _toggle('Promotions', 'Offers and bonus coin alerts', _notifPromo, (v) => setState(() => _notifPromo = v)),
          ]),
          _section('Privacy', [
            _tile(Icons.lock_outline, 'Change Password', () {}),
            _tile(Icons.block_outlined, 'Blocked Users', () {}),
            _tile(Icons.history, 'Report History', () {}),
          ]),
          _section('Language', [
            _tile(Icons.language, 'App Language', _showLanguagePicker),
          ]),
          _section('Account', [
            _tile(Icons.logout, 'Logout', _logout, color: AppColors.warning),
            _tile(Icons.delete_forever_outlined, 'Delete Account', _deleteAccount, color: AppColors.error),
          ]),
          const SizedBox(height: 32),
          const Text('Version 1.0.2', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textHint, letterSpacing: 1)),
      ),
      AppCard(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.zero,
        child: Column(children: children),
      ),
    ]);
  }

  Widget _toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
      trailing: Switch(value: value, onChanged: onChanged, activeTrackColor: AppColors.primary),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: (color ?? AppColors.primary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color ?? AppColors.textSecondary, size: 17)),
      title: Text(title, style: TextStyle(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
      onTap: onTap,
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Select Language', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        ...['English', 'Hindi', 'Gujarati'].map((lang) => ListTile(
          title: Text(lang),
          onTap: () => Navigator.pop(context),
        )),
        const SizedBox(height: 16),
      ]),
    );
  }
}
