// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart';

void main(List<String> args) {
  if (args.length < 3) {
    print(
      'Usage: dart run bin/slice.dart <image_path> <output_dir> <direction> [frames]',
    );
    exit(1);
  }

  final imagePath = args[0];
  final outputDir = args[1];
  final direction = args[2];
  final frames = args.length > 3 ? int.parse(args[3]) : 6;

  final imageFile = File(imagePath);
  if (!imageFile.existsSync()) {
    print('Error: Image not found at $imagePath');
    exit(1);
  }

  final image = decodeImage(imageFile.readAsBytesSync());
  if (image == null) {
    print('Error: Could not decode image');
    exit(1);
  }

  final frameWidth = image.width ~/ frames;
  final height = image.height;

  Directory(outputDir).createSync(recursive: true);

  for (var i = 0; i < frames; i++) {
    final x = i * frameWidth;
    final frame = copyCrop(
      image,
      x: x,
      y: 0,
      width: frameWidth,
      height: height,
    );

    // Resize to 30x30 if not already (optional safety, but let's stick to slicing for now and assume input is correct strip)
    // Actually, user inputs might be arbitrary size. Let's just slice.

    final outPath = '$outputDir/duck-walk-$direction-${i + 1}.png';
    File(outPath).writeAsBytesSync(encodePng(frame));
    print('Saved $outPath');
  }
}
