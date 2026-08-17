class ApiEndpoints {
  // Auth
  static const authGoogle = '/auth/google';
  static const authRegister = '/auth/register';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';

  // Users
  static const me = '/users/me';
  static const wallet = '/users/wallet'; // shortcut
  static const devices = '/users/devices';

  // Settings
  static const appSettings = '/settings';

  // Discovery
  static const listeners = '/discovery';
  static String listenerDetail(String id) => '/discovery/$id';

  // Calls
  static const initiateCall = '/calls/initiate';
  static String acceptCall(String id) => '/calls/$id/accept';
  static String endCall(String id) => '/calls/$id/end';
  static String rejectCall(String id) => '/calls/$id/reject';
  static String rateCall(String id) => '/calls/$id/rate';
  static const callHistory = '/calls/history';

  // Wallet
  static const walletBalance = '/wallet';
  static const walletTransactions = '/wallet/transactions';
  static const coinPackages = '/wallet/packages';

  // Payments
  static const createOrder = '/payments/create-order';
  static const verifyPayment = '/payments/verify';

  // Listener
  static const listenerRegister = '/listeners/register';
  static const listenerMe = '/listeners/me';
  static const listenerStatus = '/listeners/status';
  static const listenerVoiceVerify = '/listeners/voice-verify';

  // Earnings
  static const earningsSummary = '/earnings/summary';
  static const earningsHistory = '/earnings/history';

  // Payouts
  static const payouts = '/payouts';
  static const requestPayout = '/payouts/request';

  // Reports
  static const reports = '/reports';

  // Notifications
  static const notifications = '/notifications';

  // Support
  static const supportTickets = '/support';
  static String supportTicket(String id) => '/support/$id';
  static String ticketReply(String id) => '/support/$id/reply';

  // Favorites
  static const favorites = '/users/favorites';
}
