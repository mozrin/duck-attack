// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final baseDir = scriptDir.parent;
  final framesDir = Directory('${baseDir.path}/assets/images/duck/walk');
  final outputSheetPath =
      '${baseDir.path}/assets/images/duck/duck-walk-sheet-clean.png';

  if (!await framesDir.exists()) {
    print('Error: Could not find frames directory at ${framesDir.path}');
    exit(1);
  }

  final directions = ['n', 's', 'e', 'w', 'se', 'sw', 'ne', 'nw'];
  final frameCount = 6;
  final frameSize = 51; // As per the slicing script output

  final sheetWidth = frameSize * frameCount; // 51 * 6 = 306
  final sheetHeight = frameSize * directions.length; // 51 * 8 = 408

  final sheet = img.Image(
    width: sheetWidth,
    height: sheetHeight,
    numChannels: 4,
  );

  print('Packing sprites into ${sheetWidth}x$sheetHeight sheet...');

  for (var row = 0; row < directions.length; row++) {
    final direction = directions[row];
    for (var col = 0; col < frameCount; col++) {
      final frameNum = col + 1;
      final filename = 'duck-walk-$direction-$frameNum.png';
      final file = File('${framesDir.path}/$filename');

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final frameImg = img.decodePng(bytes);

        if (frameImg != null) {
          if (frameImg.width != frameSize || frameImg.height != frameSize) {
            print(
              'Warning: Frame $filename is ${frameImg.width}x${frameImg.height}, expected ${frameSize}x$frameSize.',
            );
          }

          final destX = col * frameSize;
          final destY = row * frameSize;

          img.compositeImage(sheet, frameImg, dstX: destX, dstY: destY);
        }
      } else {
        print('Warning: Missing frame $filename');
      }
    }
  }

  await File(outputSheetPath).writeAsBytes(img.encodePng(sheet));
  print('Saved clean sprite sheet to $outputSheetPath');
}
