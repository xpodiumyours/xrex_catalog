import 'dart:typed_data';

/// Platform interface for TFLite Object Detection
/// Each platform (IO, Web, Stub) provides its own implementation
abstract class XRexTfliteObjectDetectionServicePlatform {
  const XRexTfliteObjectDetectionServicePlatform();

  Future<bool> loadModel({
    required String modelPath,
    int numThreads = 4,
  });

  Future<List<Map<String, dynamic>>?> detectObjects({
    required Uint8List imageBytes,
    required int width,
    required int height,
  });

  void dispose();
}