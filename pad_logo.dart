import 'dart:io';
import 'package:image/image.dart';

void main() async {
  print('Loading logo...');
  final file = File('assets/images/logo.png');
  final bytes = file.readAsBytesSync();
  final logo = decodeImage(bytes)!;

  // Calculate new dimensions (1.5x padding to ensure safety zone)
  final newSize = (logo.width * 1.5).round();
  final offset = (newSize - logo.width) ~/ 2;

  print('Original: ${logo.width}x${logo.height}');
  print('New: ${newSize}x${newSize} (Offset: $offset)');

  // Create new image (initialized to 0/transparent)
  final padded = Image(width: newSize, height: newSize, numChannels: 4);

  // Composite logo onto center
  compositeImage(padded, logo, dstX: offset, dstY: offset);

  // Save
  File('assets/images/logo_padded.png').writeAsBytesSync(encodePng(padded));
  print('Saved assets/images/logo_padded.png');
}
