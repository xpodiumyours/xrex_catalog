import 'dart:typed_data';

import 'xrex_tflite_object_detection_service_platform.dart';
import '../models/xrex_detected_region.dart';

/// Default stub implementation for platforms without TFLite support
class XRexTfliteObjectDetectionServicePlatformStub implements XRexTfliteObjectDetectionServicePlatform {
  const XRexTfliteObjectDetectionServicePlatformStub();

  @override
  Future<bool> loadModel({
    required String modelPath,
    int numThreads = 4,
  }) async => true;

  @override
  Future<List<Map<String, dynamic>>?> detectObjects({
    required Uint8List imageBytes,
    required int width,
    required int height,
  }) async => <Map<String, dynamic>>[];

  @override
  void dispose() {}
}