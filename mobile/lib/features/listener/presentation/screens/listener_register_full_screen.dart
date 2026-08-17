import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_scaffold.dart';
import '../../../../shared/widgets/app_card.dart';

class ListenerRegisterFullScreen extends StatefulWidget {
  final String? audioPath;
  const ListenerRegisterFullScreen({super.key, this.audioPath});
  @override
  State<ListenerRegisterFullScreen> createState() => _ListenerRegisterFullScreenState();
}

class _ListenerRegisterFullScreenState extends State<ListenerRegisterFullScreen> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _bioCtrl  = TextEditingController();
  DateTime? _dob;
  String? _selectedState;
  String? _relationshipStatus;
  final List<String> _selectedLangs = [];
  bool _audioAvail = true;
  bool _videoAvail = false;
  bool _loading = false;

  static const _languages = ['Hindi', 'English', 'Marathi', 'Bengali', 'Tamil', 'Telugu', 'Gujarati', 'Punjabi', 'Kannada', 'Malayalam'];

  static const _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
    'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
    'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Delhi', 'Jammu & Kashmir', 'Ladakh',
  ];

  static const _relationshipStatuses = [
    'Single', 'In a Relationship', 'Married', 'Divorced', 'Widowed', 'Its Complicated',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Voice verification required. Please go back and record your voice.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (_nameCtrl.text.trim().isEmpty || _dob == null || _cityCtrl.text.trim().isEmpty || _selectedState == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Name, date of birth, city and state are required'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    final age = DateTime.now().difference(_dob!).inDays ~/ 365;
    if (age < 18) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Must be 18 or older'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      await api.post(ApiEndpoints.listenerRegister, data: {
        'displayName': _nameCtrl.text.trim(),
        'dateOfBirth': _dob!.toIso8601String(),
        'city': _cityCtrl.text.trim(),
        'state': _selectedState,
        'bio': _bioCtrl.text.trim(),
        'languages': _selectedLangs,
        'relationshipStatus': _relationshipStatus,
        'isAudioAvailable': _audioAvail,
        'isVideoAvailable': _videoAvail,
      });

      if (widget.audioPath != null && File(widget.audioPath!).existsSync()) {
        final formData = FormData.fromMap({
          'audio': await MultipartFile.fromFile(widget.audioPath!, filename: 'voice_sample.m4a'),
        });
        await api.dio.post(ApiEndpoints.listenerVoiceVerify, data: formData);
      }

      if (!mounted) return;
      await SecureStorage.setProfileComplete(true);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Application Submitted!', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'Your application and voice sample are under review. You will be notified once approved.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            ElevatedButton(
              onPressed: () { Navigator.pop(context); context.go('/home'); },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('Listener Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header card
          AppCard(
            child: Column(children: [
              ShaderMask(
                shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                child: const Icon(Icons.headset_mic_rounded, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text('Complete Your Profile', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Fill in your details to start earning', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
            ]),
          ),
          const SizedBox(height: 20),

          // Voice recorded indicator
          if (widget.audioPath != null)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.success.withValues(alpha: 0.06),
              child: Row(children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Text('Voice sample recorded ✓', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600)),
              ]),
            ),
          if (widget.audioPath != null) const SizedBox(height: 16),

          // Display Name
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Display Name *', prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary)),
          ),
          const SizedBox(height: 14),

          // Date of Birth
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
                firstDate: DateTime(1950),
                lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
              );
              if (d != null) setState(() => _dob = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date of Birth *', prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.primary)),
              child: Text(
                _dob == null ? 'Select date' : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                style: TextStyle(color: _dob == null ? AppColors.textHint : AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // City
          TextField(
            controller: _cityCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'City *', prefixIcon: Icon(Icons.location_city_outlined, color: AppColors.primary), hintText: 'e.g. Vadodara'),
          ),
          const SizedBox(height: 14),

          // State dropdown
          DropdownButtonFormField<String>(
            value: _selectedState,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'State *', prefixIcon: Icon(Icons.map_outlined, color: AppColors.primary)),
            hint: const Text('Select State', style: TextStyle(color: AppColors.textHint)),
            items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _selectedState = v),
          ),
          const SizedBox(height: 14),

          // Relationship Status
          DropdownButtonFormField<String>(
            value: _relationshipStatus,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Relationship Status', prefixIcon: Icon(Icons.favorite_border_outlined, color: AppColors.primary)),
            hint: const Text('Select Status', style: TextStyle(color: AppColors.textHint)),
            items: _relationshipStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _relationshipStatus = v),
          ),
          const SizedBox(height: 14),

          // Bio
          TextField(
            controller: _bioCtrl,
            maxLines: 3,
            maxLength: 200,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'About You (optional)', prefixIcon: Icon(Icons.edit_outlined, color: AppColors.primary)),
          ),
          const SizedBox(height: 16),

          // Languages
          Text('Languages You Speak', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _languages.map((lang) {
              final selected = _selectedLangs.contains(lang);
              return GestureDetector(
                onTap: () => setState(() { selected ? _selectedLangs.remove(lang) : _selectedLangs.add(lang); }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.accentGradient : null,
                    color: selected ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? Colors.transparent : AppColors.divider),
                  ),
                  child: Text(lang, style: TextStyle(fontSize: 13, color: selected ? Colors.white : AppColors.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Call type toggles
          Text('Available for', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _toggleCard('Audio Calls', Icons.mic, _audioAvail, (v) => setState(() => _audioAvail = v))),
            const SizedBox(width: 12),
            Expanded(child: _toggleCard('Video Calls', Icons.videocam, _videoAvail, (v) => setState(() => _videoAvail = v))),
          ]),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Application'),
            ),
          ),
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
