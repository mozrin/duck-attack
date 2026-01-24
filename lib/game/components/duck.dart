import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:duck_attack/game/config.dart';
import 'package:duck_attack/game/components/breadcrumb_lure.dart';
import 'package:duck_attack/game/components/grandma.dart';
import 'package:duck_attack/game/duck_attack_game.dart';
import 'package:duck_attack/game/systems/ai/behavior_tree.dart';
import 'package:duck_attack/game/systems/ai/steering.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

enum DuckState { seekBench, eat, flee, idle, stunned }

class DuckComponent extends SpriteAnimationComponent
    with HasGameReference<DuckAttackGame>, CollisionCallbacks {
  DuckComponent({required this.startPosition})
    : super(
        size: Vector2(30, 30),
        position: startPosition,
        anchor: Anchor.center,
      );

  final Vector2 startPosition;

  DuckState _state = DuckState.seekBench;
  DuckState get state => _state;
  set state(DuckState s) {
    if (_state != s) {
      _state = s;
      _updateAnimationState();
    }
  }

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

  late final Map<String, ({double start, double end})> sourceSectors = {};

  // Cache for loaded animations: key = "state_direction" (e.g. "walk_N", "eat_S")
  final Map<String, SpriteAnimation> _animationCache = {};
  late final AssetManifest _assetManifest;

  @override
  Future<void> onLoad() async {
    // Load Asset Manifest once
    _assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    // Load Sector & Sprite Config
    try {
      final yamlString = await rootBundle.loadString(
        'assets/images/sprites/sprites.yaml',
      );
      final yamlMap = loadYaml(yamlString) as YamlMap;

      // Load Sectors
      if (yamlMap.containsKey('sectors')) {
        final sectors = yamlMap['sectors'] as YamlMap;
        for (final key in sectors.keys) {
          final value = sectors[key] as YamlList;
          sourceSectors[key as String] = (
            start: (value[0] as num).toDouble(),
            end: (value[1] as num).toDouble(),
          );
        }
      }

      // Load Sprite Configs
      if (yamlMap.containsKey('images')) {
        _spriteConfig = yamlMap['images'] as YamlMap;
      }
    } catch (e) {
      print('Error loading sprites.yaml: $e');
    }

    // Preload critical fallbacks or initial state to prevent jank?
    // We'll load on demand or preload common ones.
    // Let's preload "walk_S" (default) and "walk_N" as we know they are used.
    await _getOrLoadAnimation(DuckState.seekBench, 'S'); // Default walk
    await _getOrLoadAnimation(DuckState.seekBench, 'N');

    // Initial animation
    _updateAnimationState();

    behaviorTree = _buildBehaviorTree();
    add(RectangleHitbox());
  }

  // Config loaded from yaml
  YamlMap? _spriteConfig;

  Future<SpriteAnimation> _getOrLoadAnimation(
    DuckState state,
    String directionKey,
  ) async {
    // Normalizing state for file names
    String stateName;
    switch (state) {
      case DuckState.seekBench:
      case DuckState.idle:
        stateName = 'walk';
        break;
      case DuckState.eat:
        stateName = 'eat';
        break;
      case DuckState.flee:
        stateName = 'fly';
        break;
      case DuckState.stunned:
        stateName = 'stun';
        break;
    }

    final cacheKey = '${stateName}_$directionKey';
    if (_animationCache.containsKey(cacheKey)) {
      return _animationCache[cacheKey]!;
    }

    SpriteAnimation anim;
    String dirName = directionKey.toLowerCase();

    // 1. Check YAML config for explicit definition
    // New structure: duck -> stateName -> dirName (e.g. duck -> walk -> s)
    dynamic configEntry;
    if (_spriteConfig != null) {
      // Try nested lookup for 'duck' -> stateName -> dirName
      if (_spriteConfig!.containsKey('duck')) {
        final duckConfig = _spriteConfig!['duck'];
        if (duckConfig is Map && duckConfig.containsKey(stateName)) {
          final stateConfig = duckConfig[stateName];
          if (stateConfig is Map && stateConfig.containsKey(dirName)) {
            configEntry = stateConfig[dirName];
          }
        }
      }

      // Legacy/Fallback (flat keys)
      if (configEntry == null) {
        if (_spriteConfig!.containsKey('${stateName}_$dirName')) {
          configEntry = _spriteConfig!['${stateName}_$dirName'];
        } else if (_spriteConfig!.containsKey(stateName)) {
          // Fallback to generic state name IF it makes sense (e.g. user mapped 'walk' -> 's')
          final genericEntry = _spriteConfig![stateName] as YamlMap;
          if (genericEntry.containsKey('source')) {
            // Only use if legacy format
            final source = genericEntry['source'] as String?;
            if (dirName == 's' && source != null && source.contains('south')) {
              configEntry = genericEntry;
            }
            if (dirName == 's' && stateName == 'walk') {
              configEntry = genericEntry;
            }
          }
        }
      }
    }

    if (configEntry != null && configEntry is YamlMap) {
      try {
        final sourcePath = 'assets/images/sprites/${configEntry['source']}';
        final sheetImage = await game.images.load(
          sourcePath.replaceFirst('assets/images/', ''),
        ); // flame loads from assets/images by default? No, game.images.load assumes assets/images prefix usually.
        // Actually flame's game.images.load looks in assets/images by default.
        // sourcePath defined in yaml: duck/walk/duck-walk-sheet-south.png
        // so we want assets/images/sprites/duck/walk/...
        // we pass 'sprites/${configEntry['source']}'

        final framesMap = configEntry['frames'] as YamlMap;
        final sprites = <Sprite>[];

        // Iterate 1..N
        int i = 1;
        while (framesMap.containsKey(i)) {
          final rectList = framesMap[i] as YamlList;
          final x = (rectList[0] as num).toDouble();
          final y = (rectList[1] as num).toDouble();
          final w = (rectList[2] as num).toDouble();
          final h = (rectList[3] as num).toDouble();

          sprites.add(
            Sprite(
              sheetImage,
              srcPosition: Vector2(x, y),
              srcSize: Vector2(w, h),
            ),
          );
          i++;
        }

        if (sprites.isNotEmpty) {
          anim = SpriteAnimation.spriteList(sprites, stepTime: 0.15);
          _animationCache[cacheKey] = anim;
          return anim;
        }
      } catch (e) {
        print('Error loading sprite from config [$cacheKey]: $e');
      }
    }

    // 2. Legacy File-based Fallback
    String basePath;
    if (stateName == 'walk') {
      basePath = 'assets/images/sprites/duck/walk/duck-walk-$dirName-';
    } else {
      // Legacy structure or other states if they exist
      basePath =
          'assets/images/sprites/duck/$stateName/$dirName/duck-$stateName-$dirName-';
    }

    final frame1Path = '${basePath}1.png';

    List<String> validPaths = [];
    if (_assetManifest.listAssets().contains(frame1Path)) {
      // Found! Collect frames
      int frame = 1;
      while (true) {
        final p = '$basePath$frame.png';
        if (_assetManifest.listAssets().contains(p)) {
          validPaths.add(p);
          frame++;
        } else {
          break;
        }
      }
    }

    if (validPaths.isNotEmpty) {
      // Load sprites
      final sprites = await Future.wait(
        validPaths.map(
          (p) => game.loadSprite(p.replaceFirst('assets/images/', '')),
        ),
      );
      anim = SpriteAnimation.spriteList(sprites, stepTime: 0.15);
    } else {
      // Fallbacks
      if (stateName == 'stun') {
        // Stun: Shaking Orange Square
        final s1 = await _generateFallbackSprite(
          30,
          const ui.Color(0xFFFFA500),
          0,
        );
        final s2 = await _generateFallbackSprite(
          30,
          const ui.Color(0xFFFFA500),
          2,
        );
        anim = SpriteAnimation.spriteList([s1, s2], stepTime: 0.1);
      } else {
        // Procedural single frame (White Square for Walk)
        ui.Color c = const ui.Color(0xFFFFFFFF); // Default white (walk)
        int size = 30;

        if (stateName == 'fly') {
          size = 15;
        } else if (stateName == 'eat') {
          c = const ui.Color(0xFF00FF00); // Green
        }

        final s = await _generateFallbackSprite(size, c, 0);
        anim = SpriteAnimation.spriteList([s], stepTime: 1.0);
      }
    }

    _animationCache[cacheKey] = anim;
    return anim;
  }

  Future<Sprite> _generateFallbackSprite(
    int size,
    ui.Color color,
    double offset,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..color = color;
    // Draw centered with offset
    canvas.drawRect(
      Rect.fromLTWH(offset, offset, size.toDouble(), size.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size + (offset.toInt() * 2),
      size + (offset.toInt() * 2),
    );
    return Sprite(image);
  }

  void _updateAnimationState() {
    // Re-trigger directional update to catch the new state
    _updateDirectionalAnimation();
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
      if (_stunTimer <= 0) {
        isStunned = false;
        state = DuckState.seekBench;
      }
      return;
    }

    behaviorTree.tick(dt);
    position += velocity * dt;

    // Update animation based on direction if moving and not stunned
    if (state != DuckState.stunned && velocity.length > 0.1) {
      _updateDirectionalAnimation();
    }
  }

  void _updateDirectionalAnimation() {
    final double rad = math.atan2(velocity.y, velocity.x);
    double deg = rad * 180 / math.pi;
    double sourceDeg = (deg + 270) % 360;
    if (sourceDeg < 0) sourceDeg += 360;

    String directionKey = 's'; // Default
    for (final entry in sourceSectors.entries) {
      final range = entry.value;
      bool match;
      if (range.start <= range.end) {
        match = sourceDeg >= range.start && sourceDeg < range.end;
      } else {
        match = sourceDeg >= range.start || sourceDeg < range.end;
      }
      if (match) {
        directionKey = entry.key;
        break;
      }
    }

    // Default to 'S' if we don't have a better idea, or if velocity is 0
    if (velocity.length < 0.1) {
      // If idle, maybe keep last direction?
      // For now let's just use S or wait for state change
      // But _updateDirectionalAnimation is called in update loop if velocity > 0.1
      // If called manually from state change, we might have 0 velocity.
    }

    // Load/Get animation
    // Ideally we don't await in update loop.
    // We should fire the load and update when ready, or rely on cache.
    // Since we can't await in update, we check cache; if missing, trigger load and set later.
    final animFuture = _getOrLoadAnimation(state, directionKey);
    animFuture.then((anim) {
      if (animation != anim) {
        animation = anim;
      }
    });

    // Dynamic Sizing: Maintain aspect ratio based on fixed width 30
    if (animation != null && animationTicker != null) {
      final currentSprite = animationTicker!.getSprite();
      final srcW = currentSprite.srcSize.x;
      final srcH = currentSprite.srcSize.y;

      if (srcW > 0) {
        final ratio = srcH / srcW;
        final newHeight = 30.0 * ratio;
        // Only update if significantly different to avoid sub-pixel jitter?
        // Just set it, Vector2 equality check might optimize internally or valid to set every frame.
        size = Vector2(30.0, newHeight);
      }
    }
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
