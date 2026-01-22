import 'package:duck_attack/game/duck_attack_game.dart';
import 'package:flutter/material.dart';

class GameOverDialog extends StatelessWidget {
  const GameOverDialog({super.key, required this.game});

  final DuckAttackGame game;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: Colors.black.withOpacity(0.8),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'GAME OVER',
                style: TextStyle(
                  fontSize: 40,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  game.reset();
                },
                child: const Text('Replay'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  // Exit logic - for now, pop to splash/main or just exit app?
                  // Design said "Exit app or return to splash".
                  // Since we are in an overlay, we might need context or game ref to navigate.
                  // Flame's GameWidget uses Navigator if available.
                  Navigator.of(context).pushReplacementNamed('/');
                },
                child: const Text('Exit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
