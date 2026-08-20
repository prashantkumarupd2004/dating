import 'package:flutter/material.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

class ListenerPrivacyScreen extends StatelessWidget {
  const ListenerPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.current;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: Text(l.privacy),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _header('Privacy Policy'),
          _meta('Last Updated: August 2025'),
          const SizedBox(height: 20),
          _intro(
            'Connecto ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our Listener app.',
          ),
          _section('1. Information We Collect', [
            'Registration Information: name, phone number, email address, gender, and profile photo.',
            'Identity Verification: voice samples collected during Listener onboarding for quality verification.',
            'Financial Information: bank/UPI details provided for payout processing (stored securely and never displayed in full).',
            'Call Metadata: call duration, call type (voice/video), call timestamps, and earnings data.',
            'Device Information: device type, OS version, push notification token (FCM), and app version.',
            'Usage Data: app interactions, screen views, and feature usage for analytics.',
          ]),
          _section('2. How We Use Your Information', [
            'To verify your identity and process Listener registration.',
            'To facilitate voice and video calls between Users and Listeners.',
            'To calculate and process your earnings and payout requests.',
            'To send you call notifications, earnings updates, and support communications.',
            'To improve platform performance, detect fraud, and ensure platform safety.',
            'To comply with applicable legal obligations.',
          ]),
          _section('3. Call Privacy', [
            'Connecto does NOT record or store audio or video content of calls.',
            'Call metadata (duration, type, timestamps) is stored for billing and earnings calculation.',
            'All calls are encrypted end-to-end using Agora\'s secure communication infrastructure.',
          ]),
          _section('4. Data Sharing', [
            'We do NOT sell your personal data to third parties.',
            'We share data with payment processors solely for payout processing.',
            'We may share anonymized, aggregated analytics data with business partners.',
            'We may disclose your information to comply with legal requirements, court orders, or regulatory obligations.',
            'In case of a merger or acquisition, your data may be transferred to the successor entity.',
          ]),
          _section('5. Data Retention', [
            'Your account data is retained for the duration of your active account.',
            'After account deletion, personal data is anonymized within 30 days.',
            'Financial transaction records are retained for 7 years as required by applicable tax regulations.',
            'Call metadata is retained for up to 12 months for dispute resolution.',
          ]),
          _section('6. Your Rights', [
            'Access: You may request a copy of the personal data we hold about you.',
            'Correction: You may update your profile information in the app at any time.',
            'Deletion: You may delete your account via Account Settings. See retention policy above.',
            'Portability: You may request your data in a portable format by contacting support.',
            'Withdrawal of Consent: You may withdraw consent to optional data processing at any time.',
          ]),
          _section('7. Security', [
            'All data is transmitted over HTTPS/TLS-encrypted connections.',
            'Sensitive information (bank details) is encrypted at rest using AES-256 encryption.',
            'We regularly audit our security practices and infrastructure.',
            'In the event of a data breach, we will notify affected users within 72 hours as required by law.',
          ]),
          _section('8. Cookies & Tracking', [
            'The Connecto app does not use browser cookies.',
            'We use Firebase Analytics and Crashlytics for app performance monitoring.',
            'You may opt out of analytics tracking from your device settings.',
          ]),
          _section('9. Children\'s Privacy', [
            'Connecto is not intended for users under 18 years of age.',
            'We do not knowingly collect personal information from minors.',
            'If we discover a minor has registered, we will immediately delete the account.',
          ]),
          _section('10. Changes to This Policy', [
            'We may update this Privacy Policy periodically.',
            'We will notify you of significant changes via in-app notification or email.',
            'Continued use of the platform after changes constitutes acceptance of the updated policy.',
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
          color: AppColors.accentStart.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentStart.withValues(alpha: 0.2)),
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
            Text('Contact Our Privacy Team', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text('For privacy-related questions or requests, contact us through the Help & Support section in the app. We will respond within 30 days of your request.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
          ]),
        ),
      );
}
