import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameState {
  final int score;
  final int health;

  const GameState({this.score = 0, this.health = 3});

  GameState copyWith({int? score, int? health}) {
    return GameState(score: score ?? this.score, health: health ?? this.health);
  }
}

class GameStateNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    return const GameState();
  }

  void addScore(int points) {
    state = state.copyWith(score: state.score + points);
  }

  void takeDamage(int damage) {
    state = state.copyWith(health: state.health - damage);
  }

  void reset() {
    state = const GameState();
  }
}

final gameStateProvider = NotifierProvider<GameStateNotifier, GameState>(() {
  return GameStateNotifier();
});
