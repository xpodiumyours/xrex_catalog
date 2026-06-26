import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xrex_catalog/services/xrex_image_preprocessing_service.dart';

void main() {
  group('XRexImagePreprocessingService', () {
    late XRexImagePreprocessingService service;
    late File tempImageFile;

    setUp(() {
      service = const XRexImagePreprocessingService();
      
      // Create a dummy image
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(255, 0, 0)); // Red background
      img.fillRect(image, x1: 20, y1: 20, x2: 80, y2: 80, color: img.ColorRgb8(0, 255, 0)); // Green square

      final bytes = img.encodeJpg(image);
      final tempDir = Directory.systemTemp.createTempSync('xrex_test');
      tempImageFile = File('${tempDir.path}/test_image.jpg');
      tempImageFile.writeAsBytesSync(bytes);
    });

    tearDown(() {
      if (tempImageFile.existsSync()) {
        tempImageFile.parent.deleteSync(recursive: true);
      }
    });

    test('preprocessImageForOcr generates an optimized file', () async {
      final resultFile = await service.preprocessImageForOcr(tempImageFile);

      expect(resultFile.existsSync(), true);
      expect(resultFile.path, isNot(tempImageFile.path));
      expect(resultFile.path.contains('optimized_ocr_'), true);

      final optimizedBytes = await resultFile.readAsBytes();
      final optimizedImage = img.decodeImage(optimizedBytes);

      expect(optimizedImage, isNotNull);
      expect(optimizedImage!.width, 100);
      expect(optimizedImage.height, 100);
    });

    test('cropProductFromBoundingBox returns cropped bytes', () async {
      final croppedBytes = await service.cropProductFromBoundingBox(
        originalImageFile: tempImageFile,
        x: 20,
        y: 20,
        width: 60,
        height: 60,
      );

      expect(croppedBytes, isNotNull);

      final croppedImage = img.decodeImage(croppedBytes!);
      expect(croppedImage, isNotNull);
      expect(croppedImage!.width, 60);
      expect(croppedImage.height, 60);
    });

    test('cropProductFromBoundingBox handles out of bounds coordinates', () async {
      final croppedBytes = await service.cropProductFromBoundingBox(
        originalImageFile: tempImageFile,
        x: -10, // Should clamp to 0
        y: -10, // Should clamp to 0
        width: 200, // Should clamp to 100 (image width)
        height: 200, // Should clamp to 100 (image height)
      );

      expect(croppedBytes, isNotNull);

      final croppedImage = img.decodeImage(croppedBytes!);
      expect(croppedImage, isNotNull);
      expect(croppedImage!.width, 100);
      expect(croppedImage.height, 100);
    });
  });
}
