import 'package:duck_attack/game/state/game_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Hud extends ConsumerWidget {
  const Hud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Score (Left)
                Expanded(
                  flex: 2,
                  child: Text(
                    '${gameState.score}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                    ),
                  ),
                ),

                // Health Bar (Center)
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: gameState.health / 100.0,
                          backgroundColor: Colors.black45,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getHealthColor(gameState.health),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // High Score (Right)
                Expanded(
                  flex: 2,
                  child: Text(
                    '${gameState.highScore}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black)],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getHealthColor(int health) {
    if (health > 60) return Colors.green;
    if (health > 30) return Colors.orange;
    return Colors.red;
  }
}
