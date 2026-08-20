import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class UserTermsScreen extends StatelessWidget {
  const UserTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text('Terms & Conditions',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _header('Terms & Conditions'),
          _meta('Last Updated: August 2025'),
          const SizedBox(height: 20),
          _intro(
            'Welcome to Connecto. By creating an account and using our platform, you agree to be bound by these Terms & Conditions. Please read them carefully.',
          ),
          _section('1. User Eligibility', [
            'You must be at least 18 years of age to use Connecto.',
            'You must provide accurate and truthful information during registration.',
            'Impersonation of any person or entity is strictly prohibited.',
            'One account per person. Creating multiple accounts may result in suspension.',
          ]),
          _section('2. User Conduct', [
            'You agree to treat all Listeners respectfully and professionally.',
            'Harassment, abuse, or inappropriate behavior will result in immediate account suspension.',
            'You must not attempt to share personal contact information with Listeners outside the platform.',
            'Recording of calls without consent is strictly prohibited.',
            'You must not use the platform for any illegal activity.',
          ]),
          _section('3. Coins & Payments', [
            'Coins are the in-app currency used to pay for calls on Connecto.',
            'Coins purchased are non-refundable unless required by applicable law.',
            'Coins are deducted per minute based on the call rate at time of connection.',
            'If a call ends unexpectedly due to a technical error, unused coins will be refunded.',
            'Connecto reserves the right to modify coin rates with prior notice.',
          ]),
          _section('4. Privacy & Data', [
            'Connecto collects and processes your data as described in our Privacy Policy.',
            'Call recordings are not stored by Connecto unless required for dispute resolution.',
            'Your personal information will never be sold to third parties.',
            'You may request deletion of your account and data at any time via Help & Support.',
          ]),
          _section('5. Intellectual Property', [
            'All content, branding, and technology on Connecto is owned by the company.',
            'You may not copy, reproduce, or distribute any part of the platform.',
            'User-generated content shared during calls remains your property.',
          ]),
          _section('6. Limitation of Liability', [
            'Connecto provides the platform "as is" without warranties of any kind.',
            'We are not liable for any indirect, incidental, or consequential damages.',
            'Our total liability shall not exceed the amount paid by you in the last 30 days.',
            'We are not responsible for the content or advice shared by Listeners.',
          ]),
          _section('7. Account Termination', [
            'You may delete your account at any time from Account Settings.',
            'Connecto may suspend or terminate accounts that violate these terms.',
            'Upon termination, unused coins may be forfeited unless otherwise stated.',
          ]),
          _section('8. Changes to Terms', [
            'Connecto may update these Terms from time to time.',
            'Continued use of the platform after changes constitutes acceptance of the new terms.',
            'We will notify you of material changes via email or in-app notification.',
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.pinkPurpleGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'For questions about these Terms, contact us through Help & Support in your profile.',
              style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _header(String t) => Text(t,
      style: GoogleFonts.poppins(
          fontSize: 22, fontWeight: FontWeight.w800,
          color: AppColors.textPrimary));

  Widget _meta(String t) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(t,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textHint)),
      );

  Widget _intro(String t) => Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.blue.withValues(alpha: 0.15)),
        ),
        child: Text(t,
            style: GoogleFonts.poppins(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
      );

  Widget _section(String title, List<String> points) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: const BoxDecoration(
                      gradient: AppColors.pinkPurpleGradient,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(child: Text(p,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AppColors.textSecondary,
                          height: 1.5))),
                ]),
              )),
          const SizedBox(height: 16),
        ],
      );
}
