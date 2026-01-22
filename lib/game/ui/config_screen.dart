import 'package:duck_attack/game/config.dart';
import 'package:flutter/material.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  void _markModified() {
    GameConfig.markModified();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isModified = GameConfig.isModified;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restore Defaults',
            onPressed: () {
              GameConfig.resetToDefaults();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restored to defaults')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isModified)
            const Card(
              color: Colors.orangeAccent,
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'WARNING: Settings are modified.\nHigh Scores will NOT be saved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

          _buildSection('Duck Settings'),
          _buildSlider('Speed', GameConfig.duckSpeed, 10, 200, (v) {
            GameConfig.duckSpeed = v;
            _markModified();
          }),
          _buildSlider('Flee Multiplier', GameConfig.duckFleeMultiplier, 1, 5, (
            v,
          ) {
            GameConfig.duckFleeMultiplier = v;
            _markModified();
          }),
          _buildSlider(
            'Spawn Rate Min (s)',
            GameConfig.duckSpawnRateMin,
            0.1,
            5,
            (v) => GameConfig.duckSpawnRateMin = v,
          ),
          _buildSlider(
            'Spawn Rate Max (s)',
            GameConfig.duckSpawnRateMax,
            0.1,
            10,
            (v) => GameConfig.duckSpawnRateMax = v,
          ),
          _buildSlider(
            'Damage',
            GameConfig.duckDamage.toDouble(),
            0,
            100,
            (v) => GameConfig.duckDamage = v.toInt(),
          ),

          _buildSection('Bread Settings'),
          _buildSlider('Lifespan (s)', GameConfig.breadLifespan, 1, 30, (v) {
            GameConfig.breadLifespan = v;
            _markModified();
          }),
        ],
      ),
    );
  }

  // Helper to handle simple updates
  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(1)}'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (v) {
            onChanged(v);
            _markModified();
          },
        ),
      ],
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
