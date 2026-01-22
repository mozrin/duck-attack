import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BreadcrumbLureComponent extends PositionComponent {
  BreadcrumbLureComponent({required Vector2 position})
    : super(size: Vector2(20, 20), position: position, anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(
      (size / 2).toOffset(),
      size.x / 2,
      Paint()..color = Colors.orangeAccent,
    );
  }
}
