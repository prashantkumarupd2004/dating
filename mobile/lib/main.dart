import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/network/api_endpoints.dart';
import 'core/providers/wallet_provider.dart';
import 'core/services/session_manager.dart';
import 'core/services/call_state_store.dart';
import 'core/services/locale_service.dart';
import 'core/socket/socket_service.dart';
import 'core/storage/secure_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FCM background message handler.
// MUST be a top-level function (not a class member) — FCM requirement.
// @pragma keeps Dart from tree-shaking it in release builds.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  if (data['type'] == 'INCOMING_CALL') {
    await _showIncomingCallNotification(
      callId:     data['callId']     ?? '',
      callerName: data['callerName'] ?? 'Unknown Caller',
      callType:   data['callType']   ?? 'AUDIO',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local notifications
// ─────────────────────────────────────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Android notification channel for incoming calls (high importance).
const AndroidNotificationChannel _callChannel = AndroidNotificationChannel(
  'incoming_calls',
  'Incoming Calls',
  description: 'Notifications for incoming audio and video calls',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

Future<void> _initLocalNotifications() async {
  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await _localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: _onNotificationTap,
  );

  final androidPlugin =
      _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_callChannel);
}

/// Called when the user taps a flutter_local_notifications notification.
void _onNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  debugPrint('📲 [NOTIFICATION_CLICKED] payload=$payload');
  if (payload != null && payload.startsWith('INCOMING_CALL:')) {
    debugPrint('📲 [FCM] Notification tapped: $payload');
  }
}

Future<void> _showIncomingCallNotification({
  required String callId,
  required String callerName,
  required String callType,
}) async {
  final isVideo = callType == 'VIDEO';
  final androidDetails = AndroidNotificationDetails(
    _callChannel.id,
    _callChannel.name,
    channelDescription: _callChannel.description,
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.call,
    playSound: true,
    enableVibration: true,
    ticker: '$callerName is calling',
    styleInformation: BigTextStyleInformation(
      '$callerName is calling you for a ${isVideo ? 'video' : 'voice'} call',
    ),
    actions: [
      const AndroidNotificationAction('DECLINE', 'Decline',
          cancelNotification: true),
      const AndroidNotificationAction('ACCEPT', 'Accept',
          cancelNotification: true),
    ],
  );

  await _localNotifications.show(
    callId.hashCode,
    isVideo ? '📹 Incoming Video Call' : '📞 Incoming Voice Call',
    callerName,
    NotificationDetails(android: androidDetails),
    payload: 'INCOMING_CALL:$callId',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MethodChannel bridge for call navigation from native
// ─────────────────────────────────────────────────────────────────────────────
const _callNavChannel = MethodChannel('com.milan.datingapp/call_navigation');
const _callFgChannel  = MethodChannel('com.milan.datingapp/call_foreground');

// ─────────────────────────────────────────────────────────────────────────────
// App entry point
// ─────────────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('⚠️ Firebase init failed: $e');
  }

  await _initLocalNotifications();

  api.init();
  walletProvider; // initialize singleton
  await sessionManager.initialize();
  await localeService.init(); // restore persisted language

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const DatingApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// Root widget
// ─────────────────────────────────────────────────────────────────────────────
class DatingApp extends StatefulWidget {
  const DatingApp({super.key});

  @override
  State<DatingApp> createState() => _DatingAppState();
}

class _DatingAppState extends State<DatingApp> with WidgetsBindingObserver {
  StreamSubscription<RemoteMessage>? _fcmForegroundSub;
  StreamSubscription<RemoteMessage>? _fcmOpenedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupFCM();

    // Set up handler for warm-start notification taps (onNewIntent from MainActivity).
    _callNavChannel.setMethodCallHandler(_handleNativeCallNavigation);

    // Check for pending call action after the first frame (cold start).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingCallAction();
    });
  }

  // ── Native → Flutter call navigation ─────────────────────────────────────

  /// Handles method calls pushed from MainActivity.onNewIntent
  /// (warm-start notification tap while the app is already running).
  Future<dynamic> _handleNativeCallNavigation(MethodCall call) async {
    if (call.method == 'onNewIntent') {
      final action = call.arguments as String?;
      debugPrint('[NOTIFICATION_CLICKED] onNewIntent action=$action');
      await _dispatchCallAction(action);
    }
  }

  /// Reads the pending call action from native (cold/warm start) and dispatches it.
  Future<void> _handlePendingCallAction() async {
    try {
      final action = await _callNavChannel.invokeMethod<String?>('getPendingCallAction');
      if (action == null) return;
      await _callNavChannel.invokeMethod('clearPendingCallAction');
      debugPrint('[NOTIFICATION_CLICKED] Cold/warm start pending action: $action');
      await _dispatchCallAction(action);
    } catch (e) {
      debugPrint('[DatingApp] _handlePendingCallAction error: $e');
    }
  }

  /// Dispatches a call navigation action — either restore the call screen or
  /// end the call cleanly.
  Future<void> _dispatchCallAction(String? action) async {
    if (action == 'OPEN_ACTIVE_CALL') {
      await _tryRestoreActiveCall();
    } else if (action == 'END_CALL') {
      await _endCallFromNotification();
    }
  }

  // ── Call restoration ──────────────────────────────────────────────────────

  /// Restores the active call screen when the user taps the ongoing notification.
  ///
  /// State machine:
  ///   1. Read persisted ActiveCallState from CallStateStore
  ///   2. If none → clean up stale notification (best-effort) and go to home
  ///   3. Validate callId against backend
  ///   4. If backend says ACTIVE → navigate to the correct call screen
  ///   5. If backend says ENDED/etc → clear local state and go to home
  Future<void> _tryRestoreActiveCall() async {
    debugPrint('[CALL_RECOVERY_STARTED] Attempting call restoration');

    final stored = await CallStateStore.instance.read();
    if (stored == null) {
      debugPrint('[CALL_RECOVERY_FAILED] No stored call state — routing to home');
      _routeToHome();
      return;
    }

    debugPrint('[CALL_RECOVERY_STARTED] Stored state: $stored — validating with backend');

    try {
      final resp = await api.get(ApiEndpoints.callStatus(stored.callId));
      final data = resp.data['data'] as Map<String, dynamic>?;
      final isActive = data?['isActive'] as bool? ?? false;
      final status   = data?['status']   as String? ?? 'UNKNOWN';

      debugPrint('[BACKEND_CALL_STATUS] callId=${stored.callId} status=$status isActive=$isActive');

      if (!isActive) {
        debugPrint('[CALL_RECOVERY_FAILED] Backend says call is $status — clearing state');
        await CallStateStore.instance.clear();
        _stopForegroundService();
        _routeToHome();
        return;
      }

      debugPrint('[CALL_RECOVERY_SUCCESS] Call is active — navigating to call screen');
      final route = stored.callType == 'VIDEO' ? '/call/video' : '/call/audio';
      appRouter.push(route, extra: stored.toRouteExtra());

    } catch (e) {
      // If we can't reach the backend, fall back to the stored state.
      // The call screen itself will detect Agora disconnect if the call ended.
      debugPrint('[CALL_RECOVERY_FAILED] Backend validation failed ($e) — restoring anyway');
      final route = stored.callType == 'VIDEO' ? '/call/video' : '/call/audio';
      appRouter.push(route, extra: stored.toRouteExtra());
    }
  }

  /// Called when the user taps "End Call" in the notification (or when
  /// the app is relaunched via TASK_REMOVED → ACTION_END_CALL intent).
  Future<void> _endCallFromNotification() async {
    debugPrint('[NOTIFICATION_END_CALL] Ending call from notification');

    final stored = await CallStateStore.instance.read();
    if (stored == null) {
      debugPrint('[NOTIFICATION_END_CALL] No stored call — nothing to end');
      return;
    }

    // Call backend end endpoint
    try {
      await api.post(ApiEndpoints.endCall(stored.callId));
      debugPrint('[NOTIFICATION_END_CALL] Backend endCall API called for ${stored.callId}');
    } catch (e) {
      debugPrint('[NOTIFICATION_END_CALL] Backend endCall failed: $e (continuing cleanup)');
    }

    // Clear local state and stop service
    await CallStateStore.instance.clear();
    _stopForegroundService();
    walletProvider.fetchBalance(force: true);
  }

  void _stopForegroundService() {
    _callFgChannel.invokeMethod('stopCallForeground').catchError((_) {});
  }

  void _routeToHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Navigate to appropriate home based on login state
      appRouter.go('/splash');
    });
  }

  // ── FCM setup ─────────────────────────────────────────────────────────────

  Future<void> _setupFCM() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, sound: true, badge: true);

    _registerFcmToken();
    messaging.onTokenRefresh.listen(_sendTokenToBackend);

    // Foreground FCM — handled by socket, no extra notification needed
    _fcmForegroundSub = FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('📩 [FCM] Foreground message: ${msg.data}');
    });

    // Background-to-foreground tap
    _fcmOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('📲 [FCM] App opened from background notification: ${msg.data}');
      _handleFcmCallMessage(msg);
    });

    // Killed-state launch
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('🚀 [FCM] App launched from killed state via notification');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleFcmCallMessage(initial);
      });
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      debugPrint('🔑 [FCM] Token: ${token.substring(0, 20)}...');
      final isLoggedIn = await SecureStorage.isLoggedIn();
      if (!isLoggedIn) return;
      await api.post(ApiEndpoints.devices, data: {
        'token':    token,
        'platform': 'android',
      });
      debugPrint('✅ [FCM] Token registered with backend');
    } catch (e) {
      debugPrint('⚠️ [FCM] Token registration failed: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await api.post(ApiEndpoints.devices, data: {
        'token':    token,
        'platform': 'android',
      });
    } catch (e) {
      debugPrint('⚠️ [FCM] Token refresh registration failed: $e');
    }
  }

  /// Handles an FCM message for an incoming call (background/killed state).
  void _handleFcmCallMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] != 'INCOMING_CALL') return;
    final callId = data['callId'] as String?;
    if (callId == null) return;
    debugPrint('📞 [FCM] Routing to listener dashboard for call: $callId');
    appRouter.go('/listener/dashboard');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fcmForegroundSub?.cancel();
    _fcmOpenedSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('[APP_${state.name.toUpperCase()}]');

    if (state == AppLifecycleState.resumed) {
      // Refresh session token when app comes back to foreground.
      sessionManager.refreshSession().then((success) {
        debugPrint(success
            ? '✅ Session refreshed on app resume'
            : '⚠️ Session refresh failed on app resume');
        if (success && socketService.isConnected == false) {
          socketService.connect();
        }
      }).catchError((e) {
        debugPrint('❌ Error refreshing session: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild MaterialApp when locale changes so all listener screens
    // immediately reflect the new language without a restart.
    return ValueListenableBuilder<Locale>(
      valueListenable: localeService.locale,
      builder: (_, locale, __) => MaterialApp.router(
        title: 'Milan',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('hi')],
        routerConfig: appRouter,
      ),
    );
  }
}
