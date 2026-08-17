import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';

class RegisterScreen extends StatefulWidget {
  final String? initialGender;
  const RegisterScreen({super.key, this.initialGender});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  DateTime? _dob;
  late String _gender;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _gender = widget.initialGender ?? 'MALE';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _dob == null || _cityCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields'), backgroundColor: AppColors.error));
      return;
    }
    final age = DateTime.now().difference(_dob!).inDays ~/ 365;
    if (age < 18) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be 18 or older'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await api.post(ApiEndpoints.authRegister, data: {
        'name': _nameCtrl.text.trim(),
        'dateOfBirth': _dob!.toIso8601String(),
        'gender': _gender,
        'city': _cityCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        await SecureStorage.setProfileComplete(true);
      } else {
        throw Exception(response.data['message'] ?? 'Registration failed');
      }
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      // Show full error in dialog so user can see exact issue
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Registration Error'),
          content: SingleChildScrollView(child: Text(e.toString())),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const AppLogo(fontSize: 22),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tell us about yourself', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text('Help others know who you are', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 28),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline, color: AppColors.primary)),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickDob,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date of Birth *', prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.primary)),
                    child: Text(
                      _dob == null ? 'Select date' : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                      style: TextStyle(color: _dob == null ? AppColors.textHint : AppColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _gender,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Gender *'),
                  items: const [
                    DropdownMenuItem(value: 'MALE', child: Text('Male')),
                    DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cityCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'City *', prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  maxLength: 200,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Short Bio (optional)',
                    prefixIcon: Icon(Icons.edit_outlined, color: AppColors.primary),
                    helperText: 'Max 200 characters',
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
