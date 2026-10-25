import 'package:flutter/material.dart';
import 'package:bike_transit/views/home.dart';
import 'package:bike_transit/views/login.dart';
import 'package:bike_transit/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bike Transit',
      themeMode: ThemeMode.system,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const RootController(title: 'Bike Transit'),
    );
  }
}

class RootController extends StatefulWidget {
  const RootController({super.key, required this.title});

  final String title;

  @override
  State<RootController> createState() => _RootControllerState();
}

class _RootControllerState extends State<RootController> {
  bool _logged_in = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged_in) {
      return const LoginPage();
    } else {
      return const HomePage();
    }
  }
}
