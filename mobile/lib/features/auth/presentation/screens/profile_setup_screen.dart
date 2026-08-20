import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_logo.dart';

// ── Preset avatars (gender-aware) ─────────────────────────────────────────────
const _maleAvatars = [
  '👦', '🧑', '👨', '🧔', '👱', '🧑‍💻', '🕵️', '🦸',
];
const _femaleAvatars = [
  '👧', '👩', '🧑‍🦰', '👸', '🧕', '🧑‍🎤', '🦹‍♀️', '🧙‍♀️',
];

class ProfileSetupScreen extends StatefulWidget {
  final String gender; // 'MALE' | 'FEMALE'
  const ProfileSetupScreen({super.key, required this.gender});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _nicknameCtrl = TextEditingController();
  int _selectedAvatar = 0;
  DateTime? _dob;
  bool _loading = false;
  late AnimationController _shimmer;
  late Animation<double> _shimmerAnim;

  bool get _isFemale => widget.gender == 'FEMALE';
  List<String> get _avatars => _isFemale ? _femaleAvatars : _maleAvatars;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _shimmerAnim = CurvedAnimation(parent: _shimmer, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.pink,
            onPrimary: Colors.white,
            surface: Color(0xFF1E1E2E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _continue() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      _showError('Please enter a nickname');
      return;
    }
    if (nickname.length < 2) {
      _showError('Nickname must be at least 2 characters');
      return;
    }
    if (_dob == null) {
      _showError('Please select your date of birth');
      return;
    }

    setState(() => _loading = true);
    try {
      final selectedEmoji = _avatars[_selectedAvatar];
      // Use emoji as avatar identifier stored in photoUrl (lightweight, no upload needed)
      final response = await api.post(ApiEndpoints.authRegister, data: {
        'name': nickname,
        'nickname': nickname,
        'dateOfBirth': _dob!.toIso8601String(),
        'gender': widget.gender,
        'photoUrl': selectedEmoji,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await SecureStorage.setProfileComplete(true);
      } else {
        throw Exception(response.data['message'] ?? 'Setup failed');
      }

      if (!mounted) return;

      if (_isFemale) {
        // Female → go to voice verification → listener registration
        context.go('/listener/voice-verify');
      } else {
        // Male → go to home as normal user
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(child: const AppLogo(fontSize: 24)),
                const SizedBox(height: 28),

                // Title
                Center(
                  child: Text('Create Your Profile',
                      style: GoogleFonts.poppins(
                          fontSize: 24, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ),
                Center(
                  child: Text(
                    _isFemale
                        ? 'Set up your profile to start as a Listener'
                        : 'Set up your profile to start connecting',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),

                // Voice verification badge for female
                if (_isFemale) ...[
                  _voiceVerificationBadge(),
                  const SizedBox(height: 20),
                ],

                // Avatar picker
                _avatarSection(),
                const SizedBox(height: 24),

                // Nickname field
                _nicknameField(),
                const SizedBox(height: 16),

                // DOB picker
                _dobPicker(),
                const SizedBox(height: 36),

                // Continue button
                _continueButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Voice Verification Badge ───────────────────────────────────────────────

  Widget _voiceVerificationBadge() {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (_, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF4D6D).withValues(alpha: 0.15 + _shimmerAnim.value * 0.08),
              const Color(0xFF7C4DFF).withValues(alpha: 0.15 + _shimmerAnim.value * 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.pink.withValues(alpha: 0.5 + _shimmerAnim.value * 0.3),
          ),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.pinkPurpleGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.4),
                  blurRadius: 12)],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Voice Verification Required',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 14,
                      color: AppColors.textPrimary)),
              Text(
                'As a Listener, you must complete a quick voice verification after this step.',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          )),
        ]),
      ),
    );
  }

  // ── Avatar Section ─────────────────────────────────────────────────────────

  Widget _avatarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose Your Avatar',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 15,
                color: AppColors.textPrimary)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: _avatars.length,
          itemBuilder: (_, i) => _AvatarTile(
            emoji: _avatars[i],
            selected: _selectedAvatar == i,
            gender: widget.gender,
            onTap: () => setState(() => _selectedAvatar = i),
          ),
        ),
      ],
    );
  }

  // ── Nickname Field ─────────────────────────────────────────────────────────

  Widget _nicknameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Nickname',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, fontSize: 15,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.12),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: TextField(
            controller: _nicknameCtrl,
            maxLength: 20,
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: _isFemale ? 'e.g. Priya, Angel, Star...' : 'e.g. Rahul, Rocky, Arjun...',
              hintStyle: GoogleFonts.poppins(color: AppColors.textHint),
              prefixIcon: const Icon(Icons.person_rounded, color: AppColors.pink),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This is what Listeners/Users will see — make it fun! 😊',
          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textHint),
        ),
      ],
    );
  }

  // ── DOB Picker ─────────────────────────────────────────────────────────────

  Widget _dobPicker() {
    return GestureDetector(
      onTap: _pickDob,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          const Icon(Icons.cake_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date of Birth',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppColors.textHint,
                      fontWeight: FontWeight.w500)),
              Text(
                _dob == null
                    ? 'Select your birthday'
                    : DateFormat('d MMMM yyyy').format(_dob!),
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: _dob == null ? AppColors.textHint : AppColors.textPrimary),
              ),
            ],
          )),
          Icon(
            _dob == null ? Icons.expand_more_rounded : Icons.check_circle_rounded,
            color: _dob == null ? AppColors.textHint : AppColors.success,
          ),
        ]),
      ),
    );
  }

  // ── Continue Button ────────────────────────────────────────────────────────

  Widget _continueButton() {
    return GestureDetector(
      onTap: _loading ? null : _continue,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: _loading ? null : AppColors.pinkPurpleGradient,
          color: _loading ? AppColors.divider : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _loading ? [] : [
            BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.4),
                blurRadius: 18, offset: const Offset(0, 6)),
          ],
        ),
        child: Center(
          child: _loading
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _isFemale ? 'Continue to Voice Verify' : 'Start Exploring',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ]),
        ),
      ),
    );
  }
}

// ── Avatar Tile Widget ─────────────────────────────────────────────────────────

class _AvatarTile extends StatelessWidget {
  final String emoji;
  final bool selected;
  final String gender;
  final VoidCallback onTap;

  const _AvatarTile({
    required this.emoji,
    required this.selected,
    required this.gender,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = gender == 'FEMALE'
        ? [const Color(0xFFFF4D6D), const Color(0xFF7C4DFF)]
        : [const Color(0xFF3D7BFF), const Color(0xFF6C63FF)];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: gradientColors,
                  begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: selected ? null : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.divider,
            width: 2,
          ),
          boxShadow: selected
              ? [BoxShadow(
                  color: gradientColors[0].withValues(alpha: 0.4),
                  blurRadius: 12, spreadRadius: 1)]
              : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            if (selected)
              Positioned(
                bottom: 2, right: 2,
                child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded,
                      size: 12, color: gradientColors[0]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
