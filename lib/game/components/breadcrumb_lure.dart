import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:duck_attack/game/config.dart';

class BreadcrumbLureComponent extends SpriteComponent
    with HasGameReference<FlameGame> {
  BreadcrumbLureComponent({required Vector2 position})
    : super(size: Vector2(20, 20), position: position, anchor: Anchor.center) {
    add(RectangleHitbox());
    timeLeft = GameConfig.breadLifespan;
  }

  late double timeLeft;
  double get fadeDuration => GameConfig.breadFadeDuration;

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('sprites/bread/fallback_bread.png');
  }

  @override
  void update(double dt) {
    super.update(dt);
    timeLeft -= dt;
    if (timeLeft <= 0) {
      removeFromParent();
      return;
    }

    // Opacity
    if (timeLeft < fadeDuration) {
      final opacity = (timeLeft / fadeDuration).clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: opacity);
    }
  }
}
