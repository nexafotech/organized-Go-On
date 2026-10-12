import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/services/face_detector_service.dart';

void main() {
  group('Face Detector Service Comprehensive Tests', () {
    test('1. Model initialization and default state', () {
      final service = HybridMobileFaceDetectorService();
      expect(service.isProcessing, false);
      expect(service.lastResult, null);
      expect(service.errorMessage, null);
    });

    test('2. Missing model weight binary returns MISSING_MODEL_WEIGHTS status', () async {
      final service = HybridMobileFaceDetectorService();
      final dummyFile = File('test/test_input.jpg');
      await dummyFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

      final result = await service.detectFaces(dummyFile);

      expect(result.imagePath, dummyFile.path);
      expect(result.isWeightsAvailable, false);
      expect(result.facesDetected, 0);
      expect(result.statusMessage.contains('MISSING_MODEL_WEIGHTS'), true);

      if (await dummyFile.exists()) {
        await dummyFile.delete();
      }
    });

    test('3. Malformed image file or non-existent path handles failure gracefully', () async {
      final service = HybridMobileFaceDetectorService();
      final missingFile = File('test/non_existent_file.jpg');

      expect(() => service.detectFaces(missingFile), throwsA(isA<Exception>()));
    });

    test('4. FaceBoundingBox serializes to JSON correctly', () {
      const box = FaceBoundingBox(x: 120, y: 80, width: 200, height: 200);
      final json = box.toJson();

      expect(json['x'], 120);
      expect(json['y'], 80);
      expect(json['width'], 200);
      expect(json['height'], 200);
    });

    test('5. DetectedFaceCrop model parsing and structure', () {
      const crop = DetectedFaceCrop(
        index: 0,
        boundingBox: FaceBoundingBox(x: 50, y: 50, width: 100, height: 100),
        confidence: 0.95,
      );

      expect(crop.index, 0);
      expect(crop.confidence, 0.95);
      expect(crop.boundingBox.width, 100);
    });
  });
}
