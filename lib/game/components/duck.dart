import 'dart:math' as math;
import 'package:duck_attack/game/config.dart';
import 'package:duck_attack/game/components/breadcrumb_lure.dart';
import 'package:duck_attack/game/components/grandma.dart';
import 'package:duck_attack/game/duck_attack_game.dart';
import 'package:duck_attack/game/systems/ai/behavior_tree.dart';
import 'package:duck_attack/game/systems/ai/steering.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum DuckState { seekBench, eat, flee, idle, stunned }

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

  // Stun logic
  bool isStunned = false;
  double _stunTimer = 0.0;
  final double _stunDuration = GameConfig.duckStunDuration;

  void stun() {
    isStunned = true;
    _stunTimer = _stunDuration;
    state = DuckState.stunned;
    velocity = Vector2.zero(); // Stop immediately
  }

  @override
  Future<void> onLoad() async {
    // TODO: Load duck sprite
    behaviorTree = _buildBehaviorTree();
    add(RectangleHitbox());
  }

  // Eating/Fullness Logic
  int crumbsEaten = 0;
  final int maxCrumbs = 1; // Full after 1 crumb
  double _eatTimer = 0.0;
  final double _eatDuration = GameConfig.duckEatDuration;

  Node _buildBehaviorTree() {
    return Selector([
      // Priority 0: Stunned (High priority override)
      ConditionNode(() => isStunned),

      // Priority 1: Fleeing (Once decided to flee, keep fleeing)
      Sequence([
        ConditionNode(() => state == DuckState.flee),
        ActionNode((dt) {
          final center = game.size / 2;
          final fleeVector = (position - center).normalized();
          velocity =
              fleeVector * GameConfig.duckSpeed * GameConfig.duckFleeMultiplier;

          // Remove if off-screen
          if (!game.camera.visibleWorldRect.contains(position.toOffset())) {
            removeFromParent();
            game.addScore(50);
          }
          return NodeStatus.success;
        }),
      ]),

      // Priority 2: Eating (Busy waiting)
      Sequence([
        ConditionNode(() => _eatTimer > 0),
        ActionNode((dt) {
          state = DuckState.eat;
          velocity = Vector2.zero();
          _eatTimer -= dt;

          // Finished eating?
          if (_eatTimer <= 0) {
            crumbsEaten++;
            if (crumbsEaten >= maxCrumbs) {
              state = DuckState.flee; // Transition to flee immediately
            } else {
              state = DuckState
                  .seekBench; // Go back to seeking if not full (unlikely with max=1)
            }
          }
          return NodeStatus.success;
        }),
      ]),

      // Priority 3: Check for Lure Collision (Strict Pathing)
      ActionNode((dt) {
        // Only check lures we strictly run into
        final lures = game.children.whereType<BreadcrumbLureComponent>();
        if (lures.isEmpty) return NodeStatus.failure;

        for (final lure in lures) {
          // Strict collision radius: slightly larger than sum of radii to ensure reliable pickup
          // Duck size ~30, Lure size ~10-15.
          // Distance < (15 + 7.5) = 22.5. Let's say 25.
          final dist = position.distanceTo(lure.position);
          if (dist < 25) {
            lure.removeFromParent();
            _eatTimer = _eatDuration;
            state = DuckState.eat;
            return NodeStatus.success;
          }
        }
        return NodeStatus.failure;
      }),

      // Priority 4: Default - Seek Grandma
      ActionNode((dt) {
        state = DuckState.seekBench;
        final target = game.size / 2;
        velocity = Steering.seek(position, target, GameConfig.duckSpeed);
        return NodeStatus.success;
      }),
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isStunned) {
      _stunTimer -= dt;
      // Wobble effect: oscillate angle
      angle = 0.1 * math.sin(_stunTimer * 20); // Fast wobble

      if (_stunTimer <= 0) {
        isStunned = false;
        angle = 0; // Reset angle
        // Force seek bench state immediately so it's clear we're targeting Grandma
        state = DuckState.seekBench;
      }
      return;
    }
    // Ensure angle is reset if not stunned (safety)
    if (angle != 0) angle = 0;

    behaviorTree.tick(dt);
    position += velocity * dt;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is GrandmaComponent) {
      removeFromParent();
      game.takeDamage(GameConfig.duckDamage);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawRect(
      size.toRect(),
      Paint()..color = isStunned ? Colors.orange : Colors.yellow,
    );
  }
}
