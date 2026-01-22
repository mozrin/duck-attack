import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

class GameConfig {
  // Duck Settings
  static double duckSpeed = 50.0;
  static double duckFleeMultiplier = 2.0;
  static double duckEatDuration = 2.0;
  static double duckStunDuration = 3.0; // New
  static double duckSpawnRateMin = 1.5; // New
  static double duckSpawnRateMax = 3.0; // New
  static int duckDamage = 20; // New

  // Grandma Settings
  static int grandmaMaxHealth = 100; // New

  // Bread Settings
  static double breadLifespan = 5.0; // New
  static double breadFadeDuration = 1.0; // New

  static Future<void> load() async {
    final String yamlString = await rootBundle.loadString('assets/config.yaml');
    final Map yamlMap = loadYaml(yamlString);

    // Helper to safely get nested values
    dynamic get(List<String> keys, dynamic fallback) {
      dynamic current = yamlMap;
      for (final key in keys) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          return fallback;
        }
      }
      return current;
    }

    // Duck
    duckSpeed = (get(['duck', 'base_speed'], 50.0) as num).toDouble();
    duckFleeMultiplier = (get(['duck', 'flee_speed_multiplier'], 2.0) as num)
        .toDouble();
    duckEatDuration = (get(['duck', 'eat_duration'], 2.0) as num).toDouble();
    duckStunDuration = (get(['duck', 'stun_duration'], 3.0) as num).toDouble();
    duckSpawnRateMin = (get(['duck', 'spawn_rate_min'], 1.5) as num).toDouble();
    duckSpawnRateMax = (get(['duck', 'spawn_rate_max'], 3.0) as num).toDouble();
    duckDamage = (get(['duck', 'damage_to_player'], 20) as int);

    // Grandma
    grandmaMaxHealth = (get(['grandma', 'max_health'], 100) as int);

    // Bread
    breadLifespan = (get(['bread', 'lifespan'], 5.0) as num).toDouble();
    breadFadeDuration = (get(['bread', 'fade_duration'], 1.0) as num)
        .toDouble();

    print('GameConfig Loaded: Speed=$duckSpeed, Flee=$duckFleeMultiplier');
  }
}
