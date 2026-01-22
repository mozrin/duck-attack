import 'package:duck_attack/game/components/breadcrumb_shot.dart';
import 'package:duck_attack/game/components/grandma.dart';
import 'package:duck_attack/game/duck_attack_game.dart';
import 'package:duck_attack/game/systems/ai/behavior_tree.dart';
import 'package:duck_attack/game/systems/ai/steering.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum DuckState { seekBench, seekLure, eat, flee, idle }

class DuckComponent extends PositionComponent
    with HasGameReference<DuckAttackGame>, CollisionCallbacks {
  DuckComponent({required this.startPosition})
    : super(
        size: Vector2(30, 30),
        position: startPosition,
        anchor: Anchor.center,
      );

  final Vector2 startPosition;
  DuckState state = DuckState.seekBench;
  double speed = 50.0;
  Vector2 velocity = Vector2.zero();
  late Node behaviorTree;

  @override
  Future<void> onLoad() async {
    // TODO: Load duck sprite
    behaviorTree = _buildBehaviorTree();
    add(RectangleHitbox());
  }

  Node _buildBehaviorTree() {
    return Selector([
      // Priority 1: Seek Bench (Default for now)
      ActionNode((dt) {
        state = DuckState.seekBench;
        final target = game.size / 2; // Grandma is at center
        final steer = Steering.seek(position, target, speed);
        velocity = steer;
        return NodeStatus.success;
      }),
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    behaviorTree.tick(dt);
    position += velocity * dt;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is BreadcrumbShotComponent) {
      removeFromParent();
    } else if (other is GrandmaComponent) {
      // Game Over Logic
      debugPrint('GAME OVER: Grandma hit by Duck!');
      // For now, just remove duck or pause game
      removeFromParent();
      game.pauseEngine();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(size.toRect(), Paint()..color = Colors.yellow);
  }
}
