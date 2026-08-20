import 'package:flutter/widgets.dart';
import '../services/locale_service.dart';

/// Simple key-based localizations for listener-facing strings.
/// Add new keys as `static const String key = 'key'` then add translations below.
class AppLocalizations {
  const AppLocalizations._(this._locale);

  final String _locale;

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations._(localeService.currentCode);
  }

  /// Convenience factory — use when context isn't available.
  static AppLocalizations get current => AppLocalizations._(localeService.currentCode);

  String get(String key) => _strings[_locale]?[key] ?? _strings['en']![key] ?? key;

  // ── Quick named accessors ────────────────────────────────────────────────
  String get profile        => get('profile');
  String get earnings       => get('earnings');
  String get callHistory    => get('callHistory');
  String get helpSupport    => get('helpSupport');
  String get language       => get('language');
  String get terms          => get('terms');
  String get privacy        => get('privacy');
  String get logout         => get('logout');
  String get deleteAccount  => get('deleteAccount');
  String get dashboard      => get('dashboard');
  String get calls          => get('calls');
  String get settings       => get('settings');
  String get submit         => get('submit');
  String get cancel         => get('cancel');
  String get raiseTicket    => get('raiseTicket');
  String get subject        => get('subject');
  String get description    => get('description');
  String get myTickets      => get('myTickets');
  String get noTickets      => get('noTickets');
  String get reply          => get('reply');
  String get send           => get('send');
  String get typeMessage    => get('typeMessage');
  String get open           => get('open');
  String get resolved       => get('resolved');
  String get closed         => get('closed');
  String get english        => get('english');
  String get hindi          => get('hindi');
  String get selectLanguage => get('selectLanguage');
  String get confirmLogout  => get('confirmLogout');
  String get logoutMessage  => get('logoutMessage');
  String get confirmDelete  => get('confirmDelete');
  String get deleteMessage  => get('deleteMessage');
  String get deleteForever  => get('deleteForever');
  String get totalEarned    => get('totalEarned');
  String get availableBalance => get('availableBalance');
  String get payout         => get('payout');
  String get noEarnings     => get('noEarnings');
  String get version        => get('version');
  String get account        => get('account');

  // ── String tables ────────────────────────────────────────────────────────
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'profile':          'Profile',
      'earnings':         'Earnings',
      'callHistory':      'Call History',
      'helpSupport':      'Help & Support',
      'language':         'Language',
      'terms':            'Terms & Conditions',
      'privacy':          'Privacy Policy',
      'logout':           'Logout',
      'deleteAccount':    'Delete Account',
      'dashboard':        'Dashboard',
      'calls':            'Calls',
      'settings':         'Settings',
      'submit':           'Submit',
      'cancel':           'Cancel',
      'raiseTicket':      'Raise a Support Ticket',
      'subject':          'Subject',
      'description':      'Description',
      'myTickets':        'My Support Tickets',
      'noTickets':        'No support tickets yet.\nTap + to raise a request.',
      'reply':            'Reply',
      'send':             'Send',
      'typeMessage':      'Type your message…',
      'open':             'Open',
      'resolved':         'Resolved',
      'closed':           'Closed',
      'english':          'English',
      'hindi':            'हिंदी (Hindi)',
      'selectLanguage':   'Select Language',
      'confirmLogout':    'Logout?',
      'logoutMessage':    'Are you sure you want to log out?',
      'confirmDelete':    'Delete Account?',
      'deleteMessage':    'This will permanently delete your account and all associated data. This cannot be undone.',
      'deleteForever':    'Delete Forever',
      'totalEarned':      'Total Earned',
      'availableBalance': 'Available Balance',
      'payout':           'Payout',
      'noEarnings':       'No earnings yet',
      'version':          'Version',
      'account':          'Account',
    },
    'hi': {
      'profile':          'प्रोफ़ाइल',
      'earnings':         'कमाई',
      'callHistory':      'कॉल इतिहास',
      'helpSupport':      'सहायता',
      'language':         'भाषा',
      'terms':            'नियम और शर्तें',
      'privacy':          'गोपनीयता नीति',
      'logout':           'लॉगआउट',
      'deleteAccount':    'खाता हटाएं',
      'dashboard':        'डैशबोर्ड',
      'calls':            'कॉल',
      'settings':         'सेटिंग्स',
      'submit':           'सबमिट करें',
      'cancel':           'रद्द करें',
      'raiseTicket':      'सहायता अनुरोध भेजें',
      'subject':          'विषय',
      'description':      'विवरण',
      'myTickets':        'मेरे सहायता अनुरोध',
      'noTickets':        'अभी तक कोई अनुरोध नहीं।\n+ दबाकर नया बनाएं।',
      'reply':            'जवाब दें',
      'send':             'भेजें',
      'typeMessage':      'अपना संदेश लिखें…',
      'open':             'खुला',
      'resolved':         'हल हुआ',
      'closed':           'बंद',
      'english':          'English',
      'hindi':            'हिंदी (Hindi)',
      'selectLanguage':   'भाषा चुनें',
      'confirmLogout':    'लॉगआउट करें?',
      'logoutMessage':    'क्या आप लॉगआउट करना चाहते हैं?',
      'confirmDelete':    'खाता हटाएं?',
      'deleteMessage':    'यह आपका खाता और सभी डेटा हमेशा के लिए हटा देगा। यह क्रिया पूर्ववत नहीं हो सकती।',
      'deleteForever':    'हमेशा के लिए हटाएं',
      'totalEarned':      'कुल कमाई',
      'availableBalance': 'उपलब्ध बैलेंस',
      'payout':           'भुगतान',
      'noEarnings':       'अभी तक कोई कमाई नहीं',
      'version':          'संस्करण',
      'account':          'खाता',
    },
  };
}
