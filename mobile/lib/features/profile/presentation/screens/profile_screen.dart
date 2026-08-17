import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/providers/wallet_provider.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/coin_badge.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';

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
    // Balance is displayed from cached provider value and updated via socket
    // Removed: walletProvider.fetchBalance() — reduces unnecessary API calls
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onWalletUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final resp = await api.get(ApiEndpoints.me);
      final data = resp.data['data'];
      setState(() { _user = data; });
      // Update wallet provider with the fetched balance
      final balance = (data['wallet']?['balance'] as num?)?.toDouble() ?? 0;
      walletProvider.updateBalance(balance);
    } catch (e) {
      debugPrint('❌ Failed to load user profile: $e');
    }
    try {
      final lResp = await api.get(ApiEndpoints.listenerMe);
      if (lResp.statusCode == 200 && lResp.data['data'] != null) {
        debugPrint('✅ Listener data loaded: ${lResp.data['data']['status']}');
        setState(() => _listenerData = lResp.data['data']);
      } else {
        debugPrint('⚠️ Listener API returned non-200 or null data');
        setState(() => _listenerData = null);
      }
    } catch (e) {
      debugPrint('ℹ️ Not a listener (expected for regular users): $e');
      setState(() => _listenerData = null);
    }
    setState(() => _loading = false);
  }

  Future<void> _logout() async {
    try {
      final refresh = await SecureStorage.getRefreshToken();
      await api.post(ApiEndpoints.authLogout, data: {'refreshToken': refresh});
    } catch (_) {}

    // Clear session using session manager
    await sessionManager.clearSession();

    // Reset wallet provider
    walletProvider.reset();

    if (mounted) context.go('/auth/login');
  }

  String get _listenerStatus => _listenerData?['status'] as String? ?? '';
  bool get _isApproved => _listenerStatus == 'APPROVED';
  bool get _hasApplied => _listenerData != null;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                // Header card
                AppCard(
                  child: Row(children: [
                    Stack(children: [
                      CircleAvatar(
                        radius: 34, backgroundColor: AppColors.bgGradientBottom,
                        backgroundImage: _user?['profile']?['photoUrl'] != null ? NetworkImage(_user!['profile']['photoUrl']) : null,
                        child: _user?['profile']?['photoUrl'] == null ? const Icon(Icons.person, size: 34, color: AppColors.accentStart) : null,
                      ),
                      Positioned(bottom: 0, right: 0, child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(gradient: AppColors.accentGradient, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                        child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
                      )),
                    ]),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_user?['name'] ?? 'User', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(_user?['phone'] ?? _user?['email'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      if (_hasApplied) ...[const SizedBox(height: 4), _statusBadge()],
                    ])),
                    ListenableBuilder(
                      listenable: walletProvider,
                      builder: (context, child) {
                        return CoinBadge(balance: walletProvider.balance, onTap: () => context.push('/recharge'));
                      },
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _tile(Icons.account_balance_wallet_outlined, 'Wallet & Transactions', () => context.push('/wallet'), color: AppColors.primary),
                    _divider(),
                    _tile(Icons.add_circle_outline, 'Buy Coins', () => context.push('/recharge'), color: AppColors.gold),
                    if (!_hasApplied) ...[_divider(), _tile(Icons.headset_mic_outlined, 'Become a Listener', () => context.push('/listener/register'), color: AppColors.accentStart)],
                    if (_hasApplied && !_isApproved) ...[_divider(), _tile(Icons.hourglass_top_outlined, 'Application: $_listenerStatus', () {}, color: AppColors.busy)],
                    if (_isApproved) ...[_divider(), _tile(Icons.dashboard_outlined, 'Listener Dashboard', () => context.push('/listener/dashboard'), color: AppColors.accentStart)],
                  ]),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _tile(Icons.settings_outlined, 'Account Settings', () => context.push('/settings/account')),
                    _divider(),
                    _tile(Icons.notifications_outlined, 'Notifications', () {}),
                    _divider(),
                    _tile(Icons.help_outline, 'Help & Support', () {}),
                    _divider(),
                    _tile(Icons.description_outlined, 'Terms & Conditions', () {}),
                  ]),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: _tile(Icons.logout, 'Logout', _logout, color: AppColors.error),
                ),
                const SizedBox(height: 24),
              ]),
            ),
    );
  }

  Widget _divider() => const Divider(height: 0, indent: 54, color: AppColors.divider);

  Widget _statusBadge() {
    final colors = {'APPROVED': AppColors.success, 'PENDING': AppColors.busy, 'REJECTED': AppColors.error, 'SUSPENDED': AppColors.error};
    final labels = {'APPROVED': 'Listener: Active', 'PENDING': 'Listener: Pending Review', 'REJECTED': 'Listener: Rejected', 'SUSPENDED': 'Listener: Suspended'};
    final color = colors[_listenerStatus] ?? AppColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(labels[_listenerStatus] ?? 'Listener: $_listenerStatus', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Container(width: 34, height: 34, decoration: BoxDecoration(color: (color ?? AppColors.textSecondary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color ?? AppColors.textSecondary, size: 18)),
      title: Text(title, style: TextStyle(color: color == AppColors.error ? AppColors.error : AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: color == AppColors.error ? null : const Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
      onTap: onTap,
    );
  }
}
