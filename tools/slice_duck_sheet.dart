// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final baseDir = scriptDir.parent;
  final imagePath = '${baseDir.path}/assets/images/duck/duck-walk-sheet.png';
  final outputDir = Directory('${baseDir.path}/assets/images/duck/walk');

  if (!await File(imagePath).exists()) {
    print('Error: Could not find $imagePath');
    exit(1);
  }

  print('Output directory: ${outputDir.absolute.path}');

  if (!await outputDir.exists()) {
    await outputDir.create(recursive: true);
  }

  print('Loading image from $imagePath...');
  final imageFile = File(imagePath);
  final bytes = await imageFile.readAsBytes();
  final image = img.decodeImage(bytes);

  if (image == null) {
    print('Error: Failed to decode image.');
    exit(1);
  }

  // Convert to grayscale for analysis
  final gray = img.grayscale(image.clone());

  // Threshold: find ink (dark pixels).
  // Pixels < 200 are ink.
  // We want to count 'ink' pixels.

  final width = image.width;
  final height = image.height;

  // 1. Horizontal Projection (Rows)
  final rowSums = List<int>.filled(height, 0);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final p = gray.getPixel(x, y);
      if (p.r < 200) {
        // Assuming dark ink on white
        rowSums[y]++;
      }
    }
  }

  final rowRegions = <List<int>>[];
  bool inRow = false;
  int startY = 0;
  final minRowHeight = 20;

  for (var y = 0; y < height; y++) {
    if (rowSums[y] > 10) {
      if (!inRow) {
        inRow = true;
        startY = y;
      }
    } else {
      if (inRow) {
        inRow = false;
        if (y - startY > minRowHeight) {
          rowRegions.add([startY, y]);
        }
      }
    }
  }

  // Handle last row if it goes to edge
  if (inRow && height - startY > minRowHeight) {
    rowRegions.add([startY, height]);
  }

  print('Detected ${rowRegions.length} rows.');

  final directions = ['n', 's', 'e', 'w', 'se', 'sw', 'ne', 'nw'];

  // Fill in missing rows if needed
  if (rowRegions.length != 8) {
    print('Warning: Expected 8 rows, finding grid fallback.');
    rowRegions.clear();
    int rowH = height ~/ 8;
    for (int i = 0; i < 8; i++) {
      rowRegions.add([i * rowH, (i + 1) * rowH]);
    }
  }

  for (var i = 0; i < rowRegions.length; i++) {
    if (i >= directions.length) break;
    final rStart = rowRegions[i][0];
    final rEnd = rowRegions[i][1];
    final direction = directions[i];

    // 2. Vertical Projection (Cols)
    final colSums = List<int>.filled(width, 0);
    for (var x = 0; x < width; x++) {
      for (var y = rStart; y < rEnd; y++) {
        final p = gray.getPixel(x, y);
        if (p.r < 200) {
          colSums[x]++;
        }
      }
    }

    final colRegions = <List<int>>[];
    bool inCol = false;
    int startX = 0;
    final minColWidth = 20;

    for (var x = 0; x < width; x++) {
      if (colSums[x] > 5) {
        // Threshold for content column
        if (!inCol) {
          inCol = true;
          startX = x;
        }
      } else {
        if (inCol) {
          inCol = false;
          if (x - startX > minColWidth) {
            colRegions.add([startX, x]);
          }
        }
      }
    }
    if (inCol && width - startX > minColWidth) {
      colRegions.add([startX, width]);
    }

    // Capture last 6 columns (skipping labels)
    List<List<int>> frames = colRegions;
    if (frames.length > 6) {
      frames = frames.sublist(frames.length - 6);
    }

    print('Row $i ($direction): Found ${frames.length} frames.');

    for (var j = 0; j < frames.length; j++) {
      final cStart = frames[j][0];
      final cEnd = frames[j][1];

      // Find precise bounding box in this cell
      int minX = cEnd, minY = rEnd, maxX = cStart, maxY = rStart;
      bool found = false;

      // Scan the cell area in the gray image to find ink extent
      for (var y = rStart; y < rEnd; y++) {
        for (var x = cStart; x < cEnd; x++) {
          if (gray.getPixel(x, y).r < 200) {
            found = true;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      if (found) {
        // We found content (ink).
        // Let's add a small margin to the content box to be safe
        final margin = 2; // 2px safety margin around ink
        minX = (minX - margin).clamp(0, width);
        maxX = (maxX + margin).clamp(0, width);
        minY = (minY - margin).clamp(0, height);
        maxY = (maxY + margin).clamp(0, height);

        final contentWidth = maxX - minX;
        final contentHeight = maxY - minY;

        // Create a 50x50 canvas
        final targetSize = 51; // As per prompt "51x51 pixel box"
        final canvas = img.Image(
          width: targetSize,
          height: targetSize,
          numChannels: 4,
        );

        // Center the content on the canvas
        // Calculate position to paste content
        final destX = (targetSize - contentWidth) ~/ 2;
        final destY = (targetSize - contentHeight) ~/ 2;

        // Copy content from original image to canvas
        img.compositeImage(
          canvas,
          image,
          dstX: destX,
          dstY: destY,
          srcX: minX,
          srcY: minY,
          srcW: contentWidth,
          srcH: contentHeight,
        );

        // Encode and save
        final filename = 'duck-walk-$direction-${j + 1}.png';
        final outPath = '${outputDir.path}/$filename';
        await File(outPath).writeAsBytes(img.encodePng(canvas));
        print('Saved $outPath');
      }
    }
  }
}
