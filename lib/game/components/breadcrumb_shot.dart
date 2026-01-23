import 'package:duck_attack/game/components/breadcrumb_lure.dart';
import 'package:duck_attack/game/components/duck.dart';
import 'package:duck_attack/game/duck_attack_game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

class BreadcrumbShotComponent extends SpriteComponent
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
    sprite = await game.loadSprite('bread/fallback_bread.png');
    velocity = (targetPosition - startPosition).normalized() * speed;
    add(CircleHitbox());
  }

  // update and onCollision remain same, render removed
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
      // Destroy the shot (it's used up by the stun)
      removeFromParent();
    }
  }
}
