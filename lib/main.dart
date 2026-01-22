import 'package:duck_attack/game/duck_attack_game.dart';
import 'package:duck_attack/game/ui/game_over_dialog.dart';
import 'package:duck_attack/game/ui/hud.dart';
import 'package:duck_attack/game/ui/splash_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:duck_attack/game/config.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await GameConfig.load();
  runApp(const ProviderScope(child: DuckAttackApp()));
}

class DuckAttackApp extends ConsumerWidget {
  const DuckAttackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Duck Attack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {'/game': (context) => const GameScreen()},
    );
  }
}

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: GameWidget(
        game: DuckAttackGame(ref),
        overlayBuilderMap: {
          'hud': (BuildContext context, DuckAttackGame game) {
            return const Hud();
          },
          'game_over': (BuildContext context, DuckAttackGame game) {
            return GameOverDialog(game: game);
          },
        },
        initialActiveOverlays: const ['hud'],
      ),
    );
  }
}
