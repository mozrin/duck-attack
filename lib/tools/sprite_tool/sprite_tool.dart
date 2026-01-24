import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/extensions.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: SpriteToolApp()),
  );
}

class SpriteToolApp extends StatefulWidget {
  const SpriteToolApp({super.key});

  @override
  State<SpriteToolApp> createState() => _SpriteToolAppState();
}

class _SpriteToolAppState extends State<SpriteToolApp>
    with SingleTickerProviderStateMixin {
  // Data
  Map<String, dynamic> _rootData = {};
  final List<String> _selectedPath = [];

  // State
  bool _loading = true;
  String? _error;
  double _zoom = 1.0;
  double _speed = 1.0;

  // Selected Sprite Details
  ui.Image? _sheetImage;
  SpriteAnimation? _currentAnimation;
  SpriteAnimationTicker? _animTicker;
  Map<String, dynamic>? _currentConfig; // Modifiable copy
  String? _currentSourcePath;

  // Animation Controller
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  // Scroll Controller
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _loadData();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_animTicker != null) {
      final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
      _animTicker!.update(dt * _speed);
      setState(() {}); // Trigger repaint for animation frame and highlight
    }
    _lastElapsed = elapsed;
  }

  Future<void> _loadData() async {
    try {
      final file = File('assets/images/sprites/sprites.yaml');
      String yamlContent;
      if (await file.exists()) {
        yamlContent = await file.readAsString();
      } else {
        yamlContent = await rootBundle.loadString(
          'assets/images/sprites/sprites.yaml',
        );
      }

      final yamlMap = loadYaml(yamlContent) as YamlMap;

      if (yamlMap.containsKey('images')) {
        // Convert to standard Map
        final images = _convertYaml(yamlMap['images']) as Map<String, dynamic>;

        setState(() {
          _rootData = images;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // Helper to convert YamlMap/List to standard Dart objects recursively
  dynamic _convertYaml(dynamic node) {
    if (node is YamlMap) {
      return node.map((k, v) => MapEntry(k.toString(), _convertYaml(v)));
    } else if (node is YamlList) {
      return node.map(_convertYaml).toList();
    } else {
      return node;
    }
  }

  Future<void> _onPathChanged(int level, String? key) async {
    if (key == null) return;

    // Truncate path to current level and add new key
    if (level < _selectedPath.length) {
      _selectedPath.removeRange(level, _selectedPath.length);
    }
    _selectedPath.add(key);

    // Reset current selection
    setState(() {
      _currentAnimation = null;
      _sheetImage = null;
      _currentConfig = null;
      _error = null;
      _animTicker = null;
    });

    // Traverse to find if it's a leaf
    dynamic node = _rootData;
    for (final k in _selectedPath) {
      if (node is Map && node.containsKey(k)) {
        node = node[k];
      } else {
        return; // Path invalid?
      }
    }

    // Check if leaf
    if (node is Map &&
        node.containsKey('source') &&
        node.containsKey('frames')) {
      await _loadLeaf(node as Map<String, dynamic>);
    } else {
      // Just a directory change, UI will update dropdowns automatically
      setState(() {});
    }
  }

  Future<void> _loadLeaf(Map<String, dynamic> config) async {
    try {
      final source = config['source'] as String;
      _currentSourcePath = 'assets/images/sprites/$source';

      final flamePath = _currentSourcePath!.replaceFirst('assets/images/', '');
      final image = await Flame.images.load(flamePath);

      setState(() {
        _sheetImage = image;
        _currentConfig = config;
      });

      _buildAnimation();
    } catch (e) {
      setState(() {
        _error = "Failed to load sprite: $e";
      });
    }
  }

  void _buildAnimation() {
    if (_sheetImage == null || _currentConfig == null) return;

    try {
      final framesMap = _currentConfig!['frames'] as Map;
      final sprites = <Sprite>[];

      final sortedKeys =
          framesMap.keys.map((e) => int.parse(e.toString())).toList()..sort();

      for (final k in sortedKeys) {
        final rectList = framesMap[k.toString()] as List;
        final x = (rectList[0] as num).toDouble();
        final y = (rectList[1] as num).toDouble();
        final w = (rectList[2] as num).toDouble();
        final h = (rectList[3] as num).toDouble();

        sprites.add(
          Sprite(
            _sheetImage!,
            srcPosition: Vector2(x, y),
            srcSize: Vector2(w, h),
          ),
        );
      }

      if (sprites.isNotEmpty) {
        final anim = SpriteAnimation.spriteList(sprites, stepTime: 0.15);
        setState(() {
          _currentAnimation = anim;
          _animTicker = anim.createTicker();
          if (!_ticker.isTicking) {
            _ticker.start();
          }
        });
      }
    } catch (e) {
      debugPrint("Animation build error: $e");
    }
  }

  List<Widget> _buildDropdowns() {
    final widgets = <Widget>[];
    dynamic currentNode = _rootData;

    // Build existing levels (+1 for next level)
    for (int i = 0; i <= _selectedPath.length; i++) {
      if (currentNode is! Map) break;

      final mapNode = currentNode as Map<String, dynamic>;

      if (mapNode.containsKey('source')) break;

      final keys = mapNode.keys.toList()..sort();
      if (keys.isEmpty) break;

      final selectedValue = (i < _selectedPath.length)
          ? _selectedPath[i]
          : null;

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: DropdownButton<String>(
            value: selectedValue,
            hint: const Text("Select"),
            items: keys
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => _onPathChanged(i, val),
          ),
        ),
      );

      if (selectedValue != null && mapNode.containsKey(selectedValue)) {
        currentNode = mapNode[selectedValue];
      } else {
        break;
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Sprite Tool',
                  style: TextStyle(color: Colors.black),
                ),
                const SizedBox(width: 20),
                if (!_loading) ..._buildDropdowns(),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _loadData,
            ),
          ],
        ),
        body: Column(
          children: [
            // Top Strip (95px to accommodate scrollbar)
            Container(
              height: 95,
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: _sheetImage != null
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          trackVisibility: true,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: Center(
                                child: SizedBox(
                                  height: 75,
                                  width:
                                      (_sheetImage!.width /
                                          _sheetImage!.height) *
                                      75,
                                  child: CustomPaint(
                                    painter: SheetPainter(
                                      _sheetImage!,
                                      _currentConfig,
                                      _animTicker?.currentIndex,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : const Center(child: Text("No Sheet Loaded")),
            ),
            const Divider(height: 1),
            // Main Area
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: _currentAnimation == null || _animTicker == null
                        ? (_error != null
                              ? Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                )
                              : const Text("Select a sprite to view"))
                        : Transform.scale(
                            scale: _zoom,
                            child: SizedBox(
                              width: _animTicker!.getSprite().srcSize.x,
                              height: _animTicker!.getSprite().srcSize.y,
                              child: CustomPaint(
                                painter: AnimationPainter(
                                  _animTicker!.getSprite(),
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Zoom controls overlaid or bottom corner? Let's put in corner
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 4,
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Text("Speed:"),
                          const SizedBox(width: 8),
                          DropdownButton<double>(
                            value: _speed,
                            underline: const SizedBox(),
                            items: List.generate(20, (index) {
                              final val = (index + 1) * 0.1;
                              return DropdownMenuItem(
                                value: double.parse(val.toStringAsFixed(1)),
                                child: Text("${(val * 100).toInt()}%"),
                              );
                            }),
                            onChanged: (v) => setState(() => _speed = v!),
                          ),
                          const SizedBox(width: 16),
                          const Text("Zoom:"),
                          const SizedBox(width: 8),
                          DropdownButton<double>(
                            value: _zoom,
                            underline: const SizedBox(),
                            items: const [0.1, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text("${(e * 100).toInt()}%"),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _zoom = v!),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SheetPainter extends CustomPainter {
  final ui.Image image;
  final Map<String, dynamic>? config;
  final int? highlightedFrameIndex;

  SheetPainter(this.image, this.config, this.highlightedFrameIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (image.height == 0) return;

    // Scale context to draw image fit to height
    final scale = size.height / image.height;
    canvas.scale(scale);

    canvas.drawImage(image, Offset.zero, Paint());

    if (config != null) {
      final frames = config!['frames'] as Map;
      final keys = frames.keys.map((e) => int.parse(e.toString())).toList()
        ..sort();

      final paintHighlight = Paint()
        ..color = Colors
            .green // Bright highlight for active
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 / scale;

      for (int i = 0; i < keys.length; i++) {
        final k = keys[i];
        final r = frames[k.toString()] as List;
        final rect = Rect.fromLTWH(
          (r[0] as num).toDouble(),
          (r[1] as num).toDouble(),
          (r[2] as num).toDouble(),
          (r[3] as num).toDouble(),
        );

        if (i == highlightedFrameIndex) {
          canvas.drawRect(rect, paintHighlight);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SheetPainter oldDelegate) {
    return oldDelegate.highlightedFrameIndex != highlightedFrameIndex ||
        oldDelegate.image != image;
  }
}

class AnimationPainter extends CustomPainter {
  final Sprite sprite;

  AnimationPainter(this.sprite);

  @override
  void paint(Canvas canvas, Size size) {
    sprite.render(canvas, size: Vector2(size.width, size.height));
  }

  @override
  bool shouldRepaint(covariant AnimationPainter oldDelegate) {
    return oldDelegate.sprite != sprite;
  }
}
