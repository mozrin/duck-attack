// unused import

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Keep native splash for 3 seconds, then show app splash for 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      FlutterNativeSplash.remove();
      // Then wait another 3 seconds for app splash
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/menu');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fallback color
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background: Solid Color
          Container(color: Colors.white),
          // Foreground: Sharp, contained version (Safe text)
          Center(
            child: Image.asset('assets/images/splash.png', fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}
