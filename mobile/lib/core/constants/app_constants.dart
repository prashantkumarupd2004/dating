const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://15.252.165.123:5000/api',
);
const String socketUrl = String.fromEnvironment(
  'SOCKET_URL',
  defaultValue: 'http://15.252.165.123:5000',
);

const int audioRateDefault = 10;
const int videoRateDefault = 60;
const int minCallCoins = 10;
const int lowBalanceWarningCoins = 30;
