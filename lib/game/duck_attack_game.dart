import 'package:duck_attack/game/components/breadcrumb_lure.dart';
import 'package:duck_attack/game/components/breadcrumb_shot.dart';
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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(GrandmaComponent()..position = size / 2);
    add(WaveDirector());
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Fire breadcrumb shot
    final origin = size / 2;
    final target = event.localPosition;
    add(BreadcrumbShotComponent(startPosition: origin, targetPosition: target));
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
    ref.read(gameStateProvider.notifier).addScore(points);
  }

  void takeDamage(int damage) {
    ref.read(gameStateProvider.notifier).takeDamage(damage);
  }
}
