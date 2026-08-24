import 'dart:typed_data';

import '../../models/xrex_detected_region.dart';

abstract class XRexObjectDetectionServiceInterface {
  const XRexObjectDetectionServiceInterface();

  Future<bool> loadModel({required String modelPath, int numThreads = 4});

  Future<List<XRexDetectedRegion>> detectObjects({
    required Uint8List imageBytes,
    required int width,
    required int height,
  });

  void dispose();
}