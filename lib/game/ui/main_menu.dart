import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[900], // Dark green for grass feel
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background - Solid Color (2D)

          // Menu Content

          // Menu Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title / Logo
                Image.asset('assets/images/logo.png', height: 150),
                const SizedBox(height: 50),

                // Buttons
                _MenuButton(
                  label: 'PLAY',
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/game'),
                  color: Colors.green,
                ),
                _MenuButton(
                  label: 'CONFIG',
                  onPressed: () => Navigator.of(context).pushNamed('/config'),
                  color: Colors.orange,
                ),
                _MenuButton(
                  label: 'ABOUT',
                  onPressed: () => Navigator.of(context).pushNamed('/about'),
                  color: Colors.blue,
                ),
                _MenuButton(
                  label: 'EXIT',
                  onPressed: () {
                    if (Platform.isAndroid || Platform.isIOS) {
                      SystemNavigator.pop();
                    } else {
                      exit(0);
                    }
                  },
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _MenuButton({
    required this.label,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        width: 200,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
