import 'dart:io';
import 'package:image/image.dart' as img;

void main(List<String> args) async {
  String path = 'assets/images/duck/walk';
  if (args.isNotEmpty) {
    path = args[0];
  }

  final dir = Directory(path);
  if (!await dir.exists()) {
    print('Directory not found: ${dir.path}');
    exit(1);
  }

  // Threshold to consider a pixel "Light" (background).
  // 0 = Black, 765 = White (255+255+255).
  // We want to remove white background, so valid background is high brightness.
  // The border is "dark", so low brightness.
  const int brightnessThreshold =
      500; // conservative threshold (roughly > 166 per channel)

  await for (final entity in dir.list()) {
    if (entity is File && entity.path.endsWith('.png')) {
      print('Processing ${entity.path}...');
      final bytes = await entity.readAsBytes();
      final image = img.decodePng(bytes);

      if (image != null) {
        final width = image.width;
        final height = image.height;
        final q = <img.Point>[];
        final visited = <int>{};

        bool isLight(img.Pixel p) {
          return (p.r + p.g + p.b) > brightnessThreshold;
        }

        // Helper to get index
        int idx(int x, int y) => y * width + x;

        // 1. Seed from ALL edges
        // Top & Bottom
        for (var x = 0; x < width; x++) {
          for (var y in [0, height - 1]) {
            final p = image.getPixel(x, y);
            if (isLight(p)) {
              final i = idx(x, y);
              if (!visited.contains(i)) {
                visited.add(i);
                q.add(img.Point(x, y));
              }
            }
          }
        }
        // Left & Right
        for (var y = 0; y < height; y++) {
          for (var x in [0, width - 1]) {
            final p = image.getPixel(x, y);
            if (isLight(p)) {
              final i = idx(x, y);
              if (!visited.contains(i)) {
                visited.add(i);
                q.add(img.Point(x, y));
              }
            }
          }
        }

        if (q.isEmpty) {
          print('  No light pixels found on edges. Skipping.');
          continue;
        }

        var pixelsCleared = 0;

        // 2. Flood Fill
        while (q.isNotEmpty) {
          final p = q.removeLast();
          final x = p.x.toInt();
          final y = p.y.toInt();

          // Set to Transparent
          image.setPixelRgba(x, y, 0, 0, 0, 0);
          pixelsCleared++;

          final neighbors = [
            img.Point(x + 1, y),
            img.Point(x - 1, y),
            img.Point(x, y + 1),
            img.Point(x, y - 1),
          ];

          for (final n in neighbors) {
            if (n.x >= 0 && n.x < width && n.y >= 0 && n.y < height) {
              final nIdx = idx(n.x.toInt(), n.y.toInt());
              if (!visited.contains(nIdx)) {
                final neighborPixel = image.getPixel(n.x.toInt(), n.y.toInt());
                // We only spread to LIGHT pixels.
                // Dark pixels (border) stop the flood.
                if (isLight(neighborPixel)) {
                  visited.add(nIdx);
                  q.add(n);
                }
              }
            }
          }
        }

        // Save
        await entity.writeAsBytes(img.encodePng(image));
        print('  Done. Cleared $pixelsCleared pixels.');
      }
    }
  }
}
