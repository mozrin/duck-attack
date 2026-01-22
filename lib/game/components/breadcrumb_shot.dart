import 'package:duck_attack/game/components/breadcrumb_lure.dart';
import 'package:duck_attack/game/components/duck.dart';
import 'package:duck_attack/game/duck_attack_game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BreadcrumbShotComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<DuckAttackGame> {
  BreadcrumbShotComponent({
    required this.startPosition,
    required this.targetPosition,
  }) : super(
         size: Vector2(10, 10),
         position: startPosition,
         anchor: Anchor.center,
       );

  final Vector2 startPosition;
  final Vector2 targetPosition;
  late Vector2 velocity;
  final double speed = 300.0;

  @override
  Future<void> onLoad() async {
    velocity = (targetPosition - startPosition).normalized() * speed;
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    if ((targetPosition - position).length < speed * dt) {
      position = targetPosition;
      // Reached target, become food/lure (Spawn Lure and remove self)
      game.add(BreadcrumbLureComponent(position: position));
      removeFromParent();
    } else {
      position += velocity * dt;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is DuckComponent) {
      // Stun the duck
      other.stun();
      // Do NOT remove shot, let it pass through
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(
      (size / 2).toOffset(),
      size.x / 2,
      Paint()..color = Colors.brown,
    );
  }
}
