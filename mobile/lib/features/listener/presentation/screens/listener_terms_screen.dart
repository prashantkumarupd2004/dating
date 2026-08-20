import 'package:flutter/material.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

class ListenerTermsScreen extends StatelessWidget {
  const ListenerTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.current;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(l.terms),
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
            'Welcome to Connecto. By registering as a Listener on our platform, you agree to be bound by these Terms & Conditions. Please read them carefully before using our services.',
          ),
          _section('1. Listener Eligibility', [
            'You must be at least 18 years of age to register as a Listener.',
            'You must provide accurate and truthful information during registration.',
            'Impersonation of any person or entity is strictly prohibited.',
            'You must have the legal right to work in your country of residence.',
            'Connecto reserves the right to reject or suspend any Listener account at its sole discretion.',
          ]),
          _section('2. Listener Obligations', [
            'You agree to conduct yourself professionally and respectfully with all Users.',
            'You must not engage in harassment, abuse, or inappropriate behavior.',
            'You must not solicit personal contact information from Users outside the platform.',
            'You must not share explicit, offensive, or illegal content during calls.',
            'You must maintain the confidentiality of user conversations.',
            'You agree to be available during your indicated availability hours.',
          ]),
          _section('3. Earnings & Payments', [
            'Listeners earn a per-minute rate for completed voice and video calls.',
            'Earnings are calculated based on confirmed call durations recorded by the platform.',
            'Connecto deducts a platform service fee from gross call revenue.',
            'Payout requests are processed within 7–10 business days after verification.',
            'Connecto reserves the right to withhold earnings if fraudulent activity is detected.',
            'Minimum payout threshold applies as stated in your Listener dashboard.',
          ]),
          _section('4. Account Suspension & Termination', [
            'Connecto may suspend or terminate your Listener account for violation of these terms.',
            'Repeated user complaints may result in account review and suspension.',
            'Suspended accounts forfeit access to the platform for the duration of the suspension.',
            'Terminated accounts will receive any outstanding valid earnings after a 30-day review period.',
            'You may terminate your own account at any time from Account Settings.',
          ]),
          _section('5. Intellectual Property', [
            'All content, branding, and technology on the Connecto platform is owned by Connecto.',
            'You grant Connecto a non-exclusive license to use your profile information and public content for platform operations.',
            'You must not reverse-engineer, copy, or redistribute any part of the Connecto platform.',
          ]),
          _section('6. Privacy', [
            'Your personal information is handled in accordance with our Privacy Policy.',
            'Call audio and video content is not recorded or stored by Connecto.',
            'Anonymized usage data may be used to improve platform performance.',
          ]),
          _section('7. Limitation of Liability', [
            'Connecto is a technology platform connecting Users and Listeners. We do not guarantee continuous availability of the platform.',
            'Connecto is not liable for loss of earnings due to technical issues, network failures, or force majeure events.',
            'Our maximum liability to you shall not exceed the total earnings processed in the last 30 days.',
          ]),
          _section('8. Changes to Terms', [
            'Connecto may update these Terms & Conditions at any time.',
            'Continued use of the platform after updates constitutes acceptance of the revised terms.',
            'Material changes will be notified via the app or email.',
          ]),
          _section('9. Governing Law', [
            'These terms are governed by the laws of India.',
            'Any disputes shall be subject to the exclusive jurisdiction of courts in India.',
          ]),
          _contact(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _header(String text) => Text(
        text,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      );

  Widget _meta(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
      );

  Widget _intro(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.5)),
      );

  Widget _section(String title, List<String> points) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 6, right: 8), child: CircleAvatar(radius: 3, backgroundColor: AppColors.textHint)),
                  Expanded(child: Text(p, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5))),
                ]),
              )),
        ]),
      );

  Widget _contact() => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))]),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Contact Us', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('For questions about these Terms & Conditions, please contact our support team through the Help & Support section in the app.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
          ]),
        ),
      );
}
