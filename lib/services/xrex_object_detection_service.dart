import 'package:flutter/foundation.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

import '../models/xrex_detected_region.dart';

class XRexObjectDetectionService {
  const XRexObjectDetectionService();

  Future<List<XRexDetectedRegion>> detectObjectsFromImagePath(
    String imagePath,
  ) async {
    if (kIsWeb || imagePath.trim().isEmpty) return const [];

    final inputImage = InputImage.fromFilePath(imagePath);
    final detector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );

    try {
      final objects = await detector.processImage(inputImage);
      return List.generate(objects.length, (index) {
        final object = objects[index];
        final label = object.labels.isEmpty ? null : object.labels.first;
        return XRexDetectedRegion(
          id: 'region_${index + 1}',
          boundingBox: object.boundingBox,
          label: label?.text,
          confidence: label?.confidence,
        );
      });
    } finally {
      await detector.close();
    }
  }
}
