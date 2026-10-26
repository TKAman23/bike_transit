import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bike_transit/constants/app_config.dart';
import 'package:bike_transit/constants/theme.dart';
import 'package:bike_transit/services/auth_service.dart';
import 'package:bike_transit/services/theme_service.dart';
import 'package:bike_transit/services/web_maps_loader.dart';
import 'package:bike_transit/state/user_data_controller.dart';
import 'package:bike_transit/views/forgot_password.dart';
import 'package:bike_transit/views/login.dart';
import 'package:bike_transit/views/maps.dart';
import 'package:bike_transit/views/profile.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SharedPreferences prefs;
  try {
    await _initFirebase();
    await AuthService.restoreSession();
    prefs = await SharedPreferences.getInstance();
    await loadGoogleMapsJs(AppConfig.mapsApiKey);
  } catch (e) {
    // Never leave the native splash up: show what went wrong instead.
    runApp(StartupErrorApp(error: e));
    return;
  }
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeService(prefs)),
      ChangeNotifierProvider(create: (_) => UserDataController()),
    ],
    child: const MyApp(),
  ));
}

Future<void> _initFirebase() {
  // Android already has a native Firebase app built from google-services.json,
  // which Gradle generates with the key from config/keys.json. Reuse it rather
  // than passing options that would have to match it exactly.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return Firebase.initializeApp();
  }
  // iOS/web: the key from config/keys.json replaces the (expired) generated key.
  final options = DefaultFirebaseOptions.currentPlatform;
  return Firebase.initializeApp(
    options: AppConfig.hasMapsKey
        ? options.copyWith(apiKey: AppConfig.mapsApiKey)
        : options,
  );
}

/// Shown when startup fails, so the app never sits on the splash screen.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Bike Transit could not start',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Check that the app was run with '
                  '--dart-define-from-file=config/keys.json and that the '
                  'Firebase key is valid.\n\n$error',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bike Transit',
      debugShowCheckedModeBanner: false,
      themeMode: context.watch<ThemeService>().mode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeAnimationDuration: const Duration(milliseconds: 350),
      // Let mouse/trackpad drag the sheet and lists on web and desktop too.
      scrollBehavior: const MaterialScrollBehavior().copyWith(dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      }),
      // Signed-in riders go straight to the map.
      initialRoute: AuthService.isSignedIn ? '/maps' : '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/maps': (context) => const MapsView(),
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
}
