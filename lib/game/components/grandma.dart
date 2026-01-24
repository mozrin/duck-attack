import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

class GrandmaComponent extends SpriteComponent
    with HasGameReference<FlameGame>, TapCallbacks {
  GrandmaComponent() : super(size: Vector2(50, 50), anchor: Anchor.center) {
    add(RectangleHitbox());
  }

  @override
  @override
  void onTapUp(TapUpEvent event) {
    // Hidden trigger removed
  }

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('sprites/grandma/fallback_grandma.png');
  }
}
