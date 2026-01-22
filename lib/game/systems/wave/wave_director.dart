import 'dart:math';

import 'package:duck_attack/game/components/duck.dart';
import 'package:duck_attack/game/duck_attack_game.dart';
import 'package:flame/components.dart';

class WaveDirector extends Component with HasGameReference<DuckAttackGame> {
  double _spawnTimer = 0.0;
  final double _spawnInterval = 2.0;
  final Random _rng = Random();

  @override
  void update(double dt) {
    super.update(dt);
    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0.0;
      _spawnDuck();
    }
  }

  void _spawnDuck() {
    final gameSize = game.size;
    // Spawn at random edge
    final side = _rng.nextInt(4); // 0: top, 1: right, 2: bottom, 3: left
    Vector2 spawnPos;

    switch (side) {
      case 0: // Top
        spawnPos = Vector2(_rng.nextDouble() * gameSize.x, 0);
        break;
      case 1: // Right
        spawnPos = Vector2(gameSize.x, _rng.nextDouble() * gameSize.y);
        break;
      case 2: // Bottom
        spawnPos = Vector2(_rng.nextDouble() * gameSize.x, gameSize.y);
        break;
      case 3: // Left
        spawnPos = Vector2(0, _rng.nextDouble() * gameSize.y);
        break;
      default:
        spawnPos = Vector2.zero();
    }

    game.add(DuckComponent(startPosition: spawnPos));
  }

  void reset() {
    _spawnTimer = 0.0;
  }
}
