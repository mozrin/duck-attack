import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';

class GrandmaComponent extends SpriteComponent
    with HasGameReference<FlameGame> {
  GrandmaComponent() : super(size: Vector2(50, 50), anchor: Anchor.center) {
    add(RectangleHitbox());
  }

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('grandma/fallback_grandma.png');
  }
}
