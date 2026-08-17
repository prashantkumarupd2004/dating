import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';


class ListenerPayoutScreen extends StatefulWidget {
  const ListenerPayoutScreen({super.key});
  @override
  State<ListenerPayoutScreen> createState() => _ListenerPayoutScreenState();
}

class _ListenerPayoutScreenState extends State<ListenerPayoutScreen> {
  final _amountCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  String _method = 'UPI';
  double _availableBalance = 0;
  List<dynamic> _payouts = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        api.get(ApiEndpoints.earningsSummary),
        api.get(ApiEndpoints.payouts),
      ]);
      setState(() {
        // Backend earnings summary: { today, week, month, wallet: { availableBalance, ... } }
        _availableBalance = (results[0].data['data']?['wallet']?['availableBalance'] as num?)?.toDouble() ?? 0;
        _payouts = (results[1].data['data'] as List<dynamic>?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    if (amount > _availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Insufficient available balance'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _submitting = true);
    try {
      await api.post(ApiEndpoints.requestPayout, data: {
        'amount': amount,
        'payoutMethod': _method,
        'accountDetails': {'account': _accountCtrl.text.trim()},
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Payout requested successfully!'), backgroundColor: AppColors.success));
      _amountCtrl.clear();
      _accountCtrl.clear();
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Request Payout')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Balance card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppColors.accentStart.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text('₹${_availableBalance.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  const Text('Payout Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _method,
                    decoration: const InputDecoration(labelText: 'Payout Method'),
                    items: const [
                      DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                      DropdownMenuItem(value: 'BANK', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'PAYTM', child: Text('Paytm')),
                    ],
                    onChanged: (v) => setState(() => _method = v!),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _accountCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(labelText: _method == 'UPI' ? 'UPI ID' : 'Account / Number', hintText: _method == 'UPI' ? 'name@upi' : 'Enter details'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      hintText: 'Min ₹500',
                      suffixText: 'Available: ₹${_availableBalance.toStringAsFixed(0)}',
                      suffixStyle: const TextStyle(color: AppColors.textHint, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Request Payout'),
                  )),
                  const SizedBox(height: 28),
                  const Text('Payout History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  if (_payouts.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No payout history', style: TextStyle(color: AppColors.textSecondary))))
                  else
                    ..._payouts.map((p) => _payoutTile(p)),
                ]),
              ),
            ),
    );
  }

  Widget _payoutTile(Map<String, dynamic> p) {
    final statusColors = {
      'PAID': AppColors.success, 'APPROVED': AppColors.success,
      'REJECTED': AppColors.error, 'REQUESTED': AppColors.busy,
      'UNDER_REVIEW': AppColors.busy, 'PROCESSING': AppColors.primary,
    };
    final color = statusColors[p['status']] ?? AppColors.textHint;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('₹${double.parse(p['amount'].toString()).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
          Text(p['payoutMethod'] ?? 'UPI', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text(p['status'] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
