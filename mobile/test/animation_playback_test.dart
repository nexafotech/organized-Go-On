import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Inspect Codec getNextFrame for WebP and GIF', () async {
    final webpBytes = await File('assets/animations/face-character-transparent.webp').readAsBytes();
    final webpCodec = await ui.instantiateImageCodec(webpBytes);
    expect(webpCodec.frameCount, equals(96));
    
    final frame0 = await webpCodec.getNextFrame();
    expect(frame0.duration.inMilliseconds, inInclusiveRange(70, 95));
    expect(frame0.image.width, equals(360));
    expect(frame0.image.height, equals(470));

    final gifBytes = await File('assets/animations/face-character.gif').readAsBytes();
    final gifCodec = await ui.instantiateImageCodec(gifBytes);
    expect(gifCodec.frameCount, equals(48));
  });

  test('Verify animation progresses through distinct directional poses', () async {
    final webpBytes = await File('assets/animations/face-character-transparent.webp').readAsBytes();
    final webpCodec = await ui.instantiateImageCodec(webpBytes);

    final List<ui.Image> keyframes = [];
    // Read all 96 frames
    for (int i = 0; i < 96; i++) {
      final f = await webpCodec.getNextFrame();
      if (i == 0 || i == 24 || i == 48 || i == 72) {
        keyframes.add(f.image);
      }
    }

    expect(keyframes.length, equals(4));

    // Convert frames to byte data and verify pixel variation
    final ByteData? data0 = await keyframes[0].toByteData(format: ui.ImageByteFormat.rawRgba);
    final ByteData? dataLeft = await keyframes[1].toByteData(format: ui.ImageByteFormat.rawRgba);
    final ByteData? dataCenter = await keyframes[2].toByteData(format: ui.ImageByteFormat.rawRgba);
    final ByteData? dataRight = await keyframes[3].toByteData(format: ui.ImageByteFormat.rawRgba);

    expect(data0, isNotNull);
    expect(dataLeft, isNotNull);
    expect(dataCenter, isNotNull);
    expect(dataRight, isNotNull);

    // Compute diff between frame 0 (Front) and frame 24 (Left)
    int diffFrontLeft = 0;
    int diffFrontRight = 0;
    final bytes0 = data0!.buffer.asUint8List();
    final bytesLeft = dataLeft!.buffer.asUint8List();
    final bytesRight = dataRight!.buffer.asUint8List();

    for (int i = 0; i < bytes0.length; i += 4) {
      diffFrontLeft += (bytes0[i] - bytesLeft[i]).abs();
      diffFrontRight += (bytes0[i] - bytesRight[i]).abs();
    }

    print('Difference between Front and Left pose: $diffFrontLeft');
    print('Difference between Front and Right pose: $diffFrontRight');

    // Both should show substantial movement (over 1,000,000 pixel diff total)
    expect(diffFrontLeft, greaterThan(500000), reason: 'Character must visibly turn head to the left');
    expect(diffFrontRight, greaterThan(500000), reason: 'Character must visibly turn head to the right');
  });
}
