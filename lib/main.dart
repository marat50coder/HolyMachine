import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/loading_screen.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FLUTTER-ERROR: ${details.exceptionAsString()}');
    };
    // Hide the status and navigation bars so the game is truly fullscreen
    // and the user can't accidentally hit Back/Home while spinning.
    // Fire-and-forget: must never block startup.
    unawaited(SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    ).timeout(const Duration(seconds: 2)).catchError((_) {}));
    runApp(const HolyMachineApp());
  }, (error, stack) {
    debugPrint('UNCAUGHT: $error\n$stack');
  });
}

class HolyMachineApp extends StatefulWidget {
  const HolyMachineApp({super.key});

  @override
  State<HolyMachineApp> createState() => _HolyMachineAppState();
}

class _HolyMachineAppState extends State<HolyMachineApp>
    with WidgetsBindingObserver {
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

  // Re-apply immersive mode every time the app regains focus (the system
  // reveals the navigation bar whenever the user swipes from the edge).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
          .timeout(const Duration(seconds: 2))
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Holy Machine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0a0604),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB638),
          secondary: Color(0xFFFF7A00),
          surface: Color(0xFF1a0e07),
        ),
        fontFamily: 'Roboto',
      ),
      home: const LoadingScreen(),
    );
  }
}
