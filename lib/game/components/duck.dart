import 'dart:math' as math;
import 'package:duck_attack/game/config.dart';
import 'package:duck_attack/game/components/breadcrumb_lure.dart';
import 'package:duck_attack/game/components/grandma.dart';
import 'package:duck_attack/game/duck_attack_game.dart';
import 'package:duck_attack/game/systems/ai/behavior_tree.dart';
import 'package:duck_attack/game/systems/ai/steering.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

enum DuckState { seekBench, eat, flee, idle, stunned }

class DuckComponent extends SpriteAnimationGroupComponent<DuckState>
    with HasGameReference<DuckAttackGame>, CollisionCallbacks {
  DuckComponent({required this.startPosition})
    : super(
        size: Vector2(30, 30),
        position: startPosition,
        anchor: Anchor.center,
      );

  final Vector2 startPosition;

  DuckState get state => current ?? DuckState.seekBench;
  set state(DuckState s) => current = s;

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
    // Load Animations

    // Walk: Vertical SpriteSheet (1 column, 3 rows) from duck-walk.png
    // Image size: 2816 x 1536.
    // 3 Frames. Texture size per frame = 2816 x (1536/3) = 2816 x 512.
    final walkImage = await game.images.load('duck-walk.png');
    final walkAnim = SpriteAnimation.fromFrameData(
      walkImage,
      SpriteAnimationData.sequenced(
        amount: 3,
        stepTime: 0.15,
        textureSize: Vector2(2816, 512),
        amountPerRow: 1, // Vertical strip
      ),
    );

    // Stun: Keep existing folder/list logic (duck-stun folder still exists in assets?)
    // User mentioned deleting duck-walk folder, didn't explicitly say duck-stun.
    // Pubspec still has duck-stun.
    final stun1 = await game.loadSprite('duck-stun/duck-stun-1.png');
    final stun2 = await game.loadSprite('duck-stun/duck-stun-2.png');

    final stunAnim = SpriteAnimation.spriteList([stun1, stun2], stepTime: 0.15);

    animations = {
      DuckState.seekBench: walkAnim,
      DuckState.eat: walkAnim,
      DuckState.flee: walkAnim,
      DuckState.idle: walkAnim,
      DuckState.stunned: stunAnim,
    };

    current = DuckState.seekBench;

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

          // Face direction
          if (velocity.length > 0.1) {
            angle = math.atan2(velocity.y, velocity.x);
          }

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

        // Face direction
        if (velocity.length > 0.1) {
          angle = math.atan2(velocity.y, velocity.x);
        }

        return NodeStatus.success;
      }),
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isStunned) {
      _stunTimer -= dt;
      if (_stunTimer <= 0) {
        isStunned = false;
        state = DuckState.seekBench;
      }
      return;
    }

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
}
