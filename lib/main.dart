import 'package:duck_attack/game/config.dart';
import 'package:duck_attack/game/duck_attack_game.dart';
import 'package:duck_attack/game/ui/about_screen.dart';
import 'package:duck_attack/game/ui/config_screen.dart';
import 'package:duck_attack/game/ui/game_over_dialog.dart';
import 'package:duck_attack/game/ui/hud.dart';
import 'package:duck_attack/game/ui/main_menu.dart';
import 'package:duck_attack/game/ui/splash_screen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await GameConfig.load();
  runApp(const ProviderScope(child: DuckAttackApp()));
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/menu', builder: (context, state) => const MainMenuScreen()),
    GoRoute(path: '/game', builder: (context, state) => const GameScreen()),
    GoRoute(path: '/config', builder: (context, state) => const ConfigScreen()),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
  ],
);

class DuckAttackApp extends ConsumerWidget {
  const DuckAttackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Duck Attack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          context.go('/menu');
        },
        child: GameWidget(
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
      ),
    );
  }
}
