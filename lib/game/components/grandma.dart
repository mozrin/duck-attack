import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GrandmaComponent extends PositionComponent {
  GrandmaComponent() : super(size: Vector2(50, 50), anchor: Anchor.center) {
    add(RectangleHitbox());
  }

  @override
  Future<void> onLoad() async {
    // TODO: Load sprite
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Placeholder rendering
    canvas.drawCircle(
      (size / 2).toOffset(),
      size.x / 2,
      Paint()..color = Colors.blueGrey,
    );
  }
}
