import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/providers/wallet_provider.dart';
import 'core/services/session_manager.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Firebase init fails if google-services.json is missing or misconfigured.
    // The app will still launch; auth features won't work until Firebase is configured.
    debugPrint('⚠️ Firebase init failed: $e');
  }
  api.init();
  // Initialize wallet provider singleton
  walletProvider;
  // Initialize session manager
  await sessionManager.initialize();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const DatingApp());
}

class DatingApp extends StatefulWidget {
  const DatingApp({super.key});

  @override
  State<DatingApp> createState() => _DatingAppState();
}

class _DatingAppState extends State<DatingApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Refresh session when app resumes from background
    if (state == AppLifecycleState.resumed) {
      sessionManager.refreshSession().then((success) {
        if (success) {
          debugPrint('✅ Session refreshed on app resume');
        } else {
          debugPrint('⚠️ Session refresh failed on app resume');
        }
      }).catchError((e) {
        debugPrint('❌ Error refreshing session: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Milan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
