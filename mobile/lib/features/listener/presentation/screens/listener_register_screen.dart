import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';
import '../../../../shared/widgets/app_card.dart';

class ListenerRegisterScreen extends StatefulWidget {
  const ListenerRegisterScreen({super.key});
  @override
  State<ListenerRegisterScreen> createState() => _ListenerRegisterScreenState();
}

class _ListenerRegisterScreenState extends State<ListenerRegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  DateTime? _dob;
  bool _audioAvail = true;
  bool _videoAvail = false;
  bool _loading = false;

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _dob == null) return;
    final age = DateTime.now().difference(_dob!).inDays ~/ 365;
    if (age < 18) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Must be 18 or older'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _loading = true);
    try {
      await api.post(ApiEndpoints.listenerRegister, data: {
        'displayName': _nameCtrl.text.trim(),
        'dateOfBirth': _dob!.toIso8601String(),
        'bio': _bioCtrl.text.trim(),
        'isAudioAvailable': _audioAvail,
        'isVideoAvailable': _videoAvail,
      });
      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Application Submitted', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Your application is under review. You will be notified once approved.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [ElevatedButton(onPressed: () { Navigator.pop(context); context.go('/home'); }, child: const Text('OK'))],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration failed'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Become a Listener')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppCard(
            child: Column(children: [
              const Icon(Icons.headset_mic_rounded, size: 44, color: AppColors.accentStart),
              const SizedBox(height: 10),
              const Text('Earn by talking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Fill in the details below to apply as a listener', style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
            ]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Display Name', prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary)),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)), firstDate: DateTime(1950), lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)));
              if (d != null) setState(() => _dob = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date of Birth', prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.primary)),
              child: Text(_dob == null ? 'Select date' : '${_dob!.day}/${_dob!.month}/${_dob!.year}', style: TextStyle(color: _dob == null ? AppColors.textHint : AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(controller: _bioCtrl, maxLines: 3, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Bio', prefixIcon: Icon(Icons.edit_outlined, color: AppColors.primary))),
          const SizedBox(height: 20),
          const Text('Available for', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _toggleCard('Audio Calls', Icons.mic, _audioAvail, (v) => setState(() => _audioAvail = v))),
            const SizedBox(width: 12),
            Expanded(child: _toggleCard('Video Calls', Icons.videocam, _videoAvail, (v) => setState(() => _videoAvail = v))),
          ]),
          const SizedBox(height: 28),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit Application'),
          )),
        ]),
      ),
    );
  }

  Widget _toggleCard(String label, IconData icon, bool active, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!active),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        color: active ? AppColors.primary.withValues(alpha: 0.07) : AppColors.surface,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? AppColors.primary : AppColors.textHint, size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: TextStyle(color: active ? AppColors.primary : AppColors.textHint, fontWeight: active ? FontWeight.w700 : FontWeight.w400, fontSize: 13))),
          const SizedBox(width: 4),
          if (active) const Icon(Icons.check_circle, color: AppColors.primary, size: 15),
        ]),
      ),
    );
  }
}
