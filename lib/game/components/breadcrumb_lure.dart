import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BreadcrumbLureComponent extends PositionComponent {
  BreadcrumbLureComponent({required Vector2 position})
    : super(size: Vector2(20, 20), position: position, anchor: Anchor.center) {
    add(RectangleHitbox());
  }

  double timeLeft = 5.0;
  static const double fadeDuration = 1.0; // Last 1 second is fade out

  @override
  void update(double dt) {
    super.update(dt);
    timeLeft -= dt;
    if (timeLeft <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Calculate opacity: 1.0 normally, fades to 0.0 in last [fadeDuration] seconds
    double opacity = 1.0;
    if (timeLeft < fadeDuration) {
      opacity = (timeLeft / fadeDuration).clamp(0.0, 1.0);
    }

    // Convert to 0-255 alpha
    final int alpha = (opacity * 255).toInt();

    canvas.drawCircle(
      (size / 2).toOffset(),
      size.x / 2,
      Paint()..color = Colors.orangeAccent.withAlpha(alpha),
    );
  }
}
