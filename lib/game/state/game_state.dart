import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameState {
  final int score;
  final int highScore;
  final int health;

  const GameState({this.score = 0, this.highScore = 0, this.health = 100});

  GameState copyWith({int? score, int? highScore, int? health}) {
    return GameState(
      score: score ?? this.score,
      highScore: highScore ?? this.highScore,
      health: health ?? this.health,
    );
  }
}

class GameStateNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    _loadHighScore();
    return const GameState();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    final highScore = prefs.getInt('high_score') ?? 0;
    state = state.copyWith(highScore: highScore);
  }

  void addScore(int points) {
    final newScore = state.score + points;
    int newHighScore = state.highScore;
    if (newScore > state.highScore) {
      newHighScore = newScore;
      _saveHighScore(newHighScore);
    }
    state = state.copyWith(score: newScore, highScore: newHighScore);
  }

  Future<void> _saveHighScore(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('high_score', value);
  }

  void takeDamage(int damage) {
    state = state.copyWith(health: state.health - damage);
  }

  void reset() {
    // Keep high score, reset others
    state = GameState(highScore: state.highScore);
  }
}

final gameStateProvider = NotifierProvider<GameStateNotifier, GameState>(() {
  return GameStateNotifier();
});
