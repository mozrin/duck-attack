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
  List<FrameMetadata>? _currentFrameMetadata;
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

  // Simple YAML serializer
  String _yamlStringify(dynamic node, [int indent = 0]) {
    final prefix = ' ' * indent;
    if (node is Map) {
      final buffer = StringBuffer();

      for (final key in node.keys) {
        final val = node[key];
        buffer.write('$prefix$key:');
        if (val is Map) {
          buffer.write('\n${_yamlStringify(val, indent + 2)}');
        } else if (val is List) {
          if (val.isEmpty) {
            buffer.write(' []\n');
          } else if (val[0] is num) {
            // Inline list for coordinates
            buffer.write(' [${val.join(', ')}]\n');
          } else {
            buffer.write('\n${_yamlStringify(val, indent + 2)}');
          }
        } else {
          buffer.write(' $val\n');
        }
      }
      return buffer.toString();
    } else if (node is List) {
      return "";
    }
    return "$node";
  }

  Future<void> _saveData() async {
    try {
      final file = File('assets/images/sprites/sprites.yaml');
      String originalContent = "";
      if (await file.exists()) {
        originalContent = await file.readAsString();
      } else {
        originalContent = await rootBundle.loadString(
          'assets/images/sprites/sprites.yaml',
        );
      }

      final fullMap = _convertYaml(loadYaml(originalContent));
      if (fullMap is Map) {
        fullMap['images'] = _rootData;
      }

      final yamlString = _yamlStringify(fullMap);

      // Write
      if (await file.exists()) {
        await file.writeAsString(yamlString);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Saved sprites.yaml")));
        }
      } else {
        debugPrint(
          "Cannot save to assets bundle in run mode unless file assumes local path.",
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _buildAnimation() {
    if (_sheetImage == null || _currentConfig == null) return;

    try {
      final framesMap = _currentConfig!['frames'] as Map;
      final sprites = <Sprite>[];
      final metadata = <FrameMetadata>[];

      final sortedKeys =
          framesMap.keys.map((e) => int.parse(e.toString())).toList()..sort();

      for (final k in sortedKeys) {
        final raw = framesMap[k.toString()];
        double x, y, w, h;
        Offset? center;
        double rotation = 0;

        if (raw is List) {
          x = (raw[0] as num).toDouble();
          y = (raw[1] as num).toDouble();
          w = (raw[2] as num).toDouble();
          h = (raw[3] as num).toDouble();
        } else if (raw is Map) {
          x = (raw['left'] as num).toDouble();
          y = (raw['top'] as num).toDouble();

          if (raw.containsKey('width')) {
            w = (raw['width'] as num).toDouble();
          } else {
            w = (raw['right'] as num).toDouble();
          }

          if (raw.containsKey('height')) {
            h = (raw['height'] as num).toDouble();
          } else {
            h = (raw['bottom'] as num).toDouble();
          }

          if (raw.containsKey('center')) {
            final cList = raw['center'] as List;
            center = Offset(
              (cList[0] as num).toDouble(),
              (cList[1] as num).toDouble(),
            );
          }
          if (raw.containsKey('rotate')) {
            rotation =
                (raw['rotate'] as num).toDouble() *
                (3.14159 / 180.0); // Deg to Rad
          }
        } else {
          continue;
        }

        sprites.add(
          Sprite(
            _sheetImage!,
            srcPosition: Vector2(x, y),
            srcSize: Vector2(w, h),
          ),
        );
        metadata.add(FrameMetadata(center: center, rotation: rotation));
      }

      if (sprites.isNotEmpty) {
        final anim = SpriteAnimation.spriteList(sprites, stepTime: 0.15);
        setState(() {
          _currentAnimation = anim;
          _currentFrameMetadata = metadata;
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

  Widget _buildEditor() {
    if (_currentConfig == null ||
        _animTicker == null ||
        _currentFrameMetadata == null) {
      return const SizedBox();
    }

    final currentIndex = _animTicker!.currentIndex;
    if (currentIndex >= _currentFrameMetadata!.length) return const SizedBox();

    // Get current frame data
    // frames are 1-indexed in YAML keys usually?
    // We sorted keys list in buildAnimation.
    final framesMap = _currentConfig!['frames'] as Map;
    final sortedKeys =
        framesMap.keys.map((e) => int.parse(e.toString())).toList()..sort();
    final key = sortedKeys[currentIndex].toString();
    final frameData = framesMap[key]; // Modifiable map reference hopefully

    // We need Modifiable Map. _convertYaml ensured it's standard Map.
    if (frameData is! Map) return const Text("Cannot edit list-format frame");

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade50,
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Frame: $key",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _numInput("Left", frameData['left'], (v) => frameData['left'] = v),
          _numInput("Top", frameData['top'], (v) => frameData['top'] = v),
          _numInput("Width", frameData['width'] ?? frameData['right'], (v) {
            if (frameData.containsKey('width')) {
              frameData['width'] = v;
            } else {
              frameData['right'] = v;
            }
          }),
          _numInput("Height", frameData['height'] ?? frameData['bottom'], (v) {
            if (frameData.containsKey('height')) {
              frameData['height'] = v;
            } else {
              frameData['bottom'] = v;
            }
          }),
          const Divider(),
          const Text(
            "Anchor (Center)",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: _numInput(
                  "X",
                  (frameData['center'] as List)[0],
                  (v) => (frameData['center'] as List)[0] = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _numInput(
                  "Y",
                  (frameData['center'] as List)[1],
                  (v) => (frameData['center'] as List)[1] = v,
                ),
              ),
            ],
          ),
          const Divider(),
          _numInput(
            "Rotation",
            frameData['rotate'] ?? 0,
            (v) => frameData['rotate'] = v,
          ),
        ],
      ),
    );
  }

  Widget _numInput(String label, num value, Function(num) onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: SizedBox(
            height: 30,
            child: TextFormField(
              initialValue: value.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (str) {
                final n = num.tryParse(str);
                if (n != null) {
                  onChanged(n);
                  _buildAnimation(); // Rebuild preview
                  setState(
                    () {},
                  ); // Rebuild editor to keep sync? No input rebuilds itself.
                }
              },
            ),
          ),
        ),
      ],
    );
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
              icon: const Icon(Icons.save, color: Colors.blue),
              onPressed: _saveData,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black),
              onPressed: _loadData,
            ),
          ],
        ),
        body: Column(
          children: [
            // Top Strip
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
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Center(
                          child:
                              _currentAnimation == null || _animTicker == null
                              ? (_error != null
                                    ? Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                        ),
                                      )
                                    : const Text("Select a sprite to view"))
                              : Transform.scale(
                                  scale: _zoom,
                                  child: SizedBox(
                                    width: 300,
                                    height: 300,
                                    child: CustomPaint(
                                      painter: AnimationPainter(
                                        _animTicker!.getSprite(),
                                        _currentFrameMetadata != null &&
                                                _animTicker!.currentIndex <
                                                    _currentFrameMetadata!
                                                        .length
                                            ? _currentFrameMetadata![_animTicker!
                                                  .currentIndex]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        // Controls
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
                                IconButton(
                                  icon: Icon(
                                    _ticker.isTicking
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                  ),
                                  onPressed: () => setState(() {
                                    if (_ticker.isTicking) {
                                      _ticker.stop();
                                    } else {
                                      _ticker.start();
                                    }
                                  }),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.skip_previous),
                                  onPressed: () {
                                    _ticker.stop();
                                    // Manually step? Flame ticker isn't easy to step backward.
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.skip_next),
                                  onPressed: () {
                                    _ticker.stop();
                                    _animTicker?.update(
                                      0.1501,
                                    ); // Advance one step?
                                    setState(() {});
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Text("Speed:"),
                                DropdownButton<double>(
                                  value: _speed,
                                  underline: const SizedBox(),
                                  items: List.generate(20, (index) {
                                    final val = (index + 1) * 0.1;
                                    return DropdownMenuItem(
                                      value: double.parse(
                                        val.toStringAsFixed(1),
                                      ),
                                      child: Text("${(val * 100).toInt()}%"),
                                    );
                                  }),
                                  onChanged: (v) => setState(() => _speed = v!),
                                ),
                                const SizedBox(width: 8),
                                const Text("Zoom:"),
                                DropdownButton<double>(
                                  value: _zoom,
                                  underline: const SizedBox(),
                                  items:
                                      const [0.1, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
                                          .map(
                                            (e) => DropdownMenuItem(
                                              value: e,
                                              child: Text(
                                                "${(e * 100).toInt()}%",
                                              ),
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
                  // Editor Panel
                  if (_currentConfig != null) _buildEditor(),
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

        // Draw Center/Anchor if present
        if (frames[k.toString()] is Map &&
            (frames[k.toString()] as Map).containsKey('center')) {
          final cList = (frames[k.toString()] as Map)['center'] as List;
          final cx = (cList[0] as num).toDouble();
          final cy = (cList[1] as num).toDouble();

          final paintCenter = Paint()
            ..color = Colors.red
            ..style = PaintingStyle.fill;

          canvas.drawCircle(Offset(cx, cy), 3.0 / scale, paintCenter);
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
  final FrameMetadata? metadata;

  AnimationPainter(this.sprite, this.metadata);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw fixed world anchor (crosshair)
    final center = size.center(Offset.zero);
    final paintCrosshair = Paint()
      ..color = Colors.blue.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(center.dx - 20, center.dy),
      Offset(center.dx + 20, center.dy),
      paintCrosshair,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 20),
      Offset(center.dx, center.dy + 20),
      paintCrosshair,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);

    double rotation = 0;
    Offset anchor = Offset(
      sprite.srcSize.x / 2,
      sprite.srcSize.y / 2,
    ); // Default to geometric center

    if (metadata != null) {
      rotation = metadata!.rotation;
      if (metadata!.center != null) {
        // relative anchor = center - srcPosition
        anchor = metadata!.center! - sprite.srcPosition.toOffset();
      }
    }

    // Apply rotation
    canvas.rotate(rotation);

    // Apply anchor offset (move so anchor is at (0,0))
    canvas.translate(-anchor.dx, -anchor.dy);

    sprite.render(canvas);

    // Draw local anchor point on sprite (red dot)
    canvas.drawCircle(anchor, 3, Paint()..color = Colors.red);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AnimationPainter oldDelegate) {
    return oldDelegate.sprite != sprite || oldDelegate.metadata != metadata;
  }
}

class FrameMetadata {
  final Offset? center; // Absolute center on sheet
  final double rotation; // Radians

  FrameMetadata({this.center, this.rotation = 0});
}
