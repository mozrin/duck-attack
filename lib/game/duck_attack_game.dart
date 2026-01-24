import 'package:duck_attack/game/components/breadcrumb_lure.dart';
import 'package:duck_attack/game/components/breadcrumb_shot.dart';
import 'package:duck_attack/game/components/duck.dart';
import 'package:duck_attack/game/components/grandma.dart';
import 'package:duck_attack/game/state/game_state.dart';
import 'package:duck_attack/game/systems/wave/wave_director.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class DuckAttackGame extends FlameGame
    with TapCallbacks, LongPressDetector, HasCollisionDetection {
  DuckAttackGame(this.ref);

  final WidgetRef ref;

  double _staminaTimer = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    final gameState = ref.read(gameStateProvider);
    if (gameState.stamina < 10) {
      _staminaTimer += dt;
      // Regen rate: 1 stamina every 6 - (health / 20) seconds
      // Health 100 -> 6 - 5 = 1 sec
      // Health 0   -> 6 - 0 = 6 sec
      final regenTime = 6.0 - (gameState.health / 20.0);

      // Safety clamp
      final effectiveRegenTime = regenTime.clamp(1.0, 6.0);

      if (_staminaTimer >= effectiveRegenTime) {
        ref.read(gameStateProvider.notifier).regenStamina();
        _staminaTimer = 0.0;
      }
    } else {
      _staminaTimer = 0.0;
    }
  }

  @override
  void onLoad() async {
    await super.onLoad();
    add(GrandmaComponent()..position = size / 2);
    add(WaveDirector());
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Check stamina
    final notifier = ref.read(gameStateProvider.notifier);
    if (ref.read(gameStateProvider).stamina > 0) {
      notifier.consumeStamina();
      // Fire breadcrumb shot
      final origin = size / 2;
      final target = event.localPosition;
      add(
        BreadcrumbShotComponent(startPosition: origin, targetPosition: target),
      );
    }
  }

  @override
  void onLongPressStart(LongPressStartInfo info) {
    // Start aim mode (visuals)
  }

  @override
  void onLongPressEnd(LongPressEndInfo info) {
    // Lob breadcrumb lure
    add(BreadcrumbLureComponent(position: info.eventPosition.global));
  }

  void addScore(int points) {
    Future.microtask(() {
      ref.read(gameStateProvider.notifier).addScore(points);
    });
  }

  void takeDamage(int damage) {
    Future.microtask(() {
      ref.read(gameStateProvider.notifier).takeDamage(damage);
    });
    // Check game over logic could be done inside notifier too, but deferring here for now
    if (ref.read(gameStateProvider).health - damage <= 0) {
      // Defer this too as it likely manipulates overlays which interacts with UI
      Future.microtask(() => gameOver());
    }
  }

  void gameOver() {
    pauseEngine();
    overlays.add('game_over');
  }

  void reset() {
    overlays.remove('game_over');
    ref.read(gameStateProvider.notifier).reset();

    // Clear enemies and shots
    children.whereType<DuckComponent>().forEach((d) => d.removeFromParent());
    children.whereType<BreadcrumbShotComponent>().forEach(
      (s) => s.removeFromParent(),
    );
    children.whereType<BreadcrumbLureComponent>().forEach(
      (l) => l.removeFromParent(),
    );
    children.whereType<WaveDirector>().forEach((w) => w.reset());

    resumeEngine();
  }
}
