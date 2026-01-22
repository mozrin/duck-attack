import 'package:duck_attack/game/ui/about_screen.dart';
import 'package:duck_attack/game/ui/config_screen.dart';
import 'package:duck_attack/game/ui/main_menu.dart';

// ...

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Duck Attack',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/menu': (context) => const MainMenuScreen(),
        '/game': (context) => const GameScreen(),
        '/config': (context) => const ConfigScreen(),
        '/about': (context) => const AboutScreen(),
      },
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
