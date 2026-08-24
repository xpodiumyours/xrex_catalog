import 'dart:typed_data';

import '../models/xrex_detected_region.dart';
import 'interfaces/xrex_object_detection_service.dart';

class XRexTfliteObjectDetectionServiceWeb implements XRexObjectDetectionServiceInterface {
  static final XRexTfliteObjectDetectionServiceWeb _instance = XRexTfliteObjectDetectionServiceWeb._internal();
  factory XRexTfliteObjectDetectionServiceWeb() => _instance;
  XRexTfliteObjectDetectionServiceWeb._internal();

  bool _isModelLoaded = false;

  @override
  Future<bool> loadModel({required String modelPath, int numThreads = 4}) async {
    if (_isModelLoaded) return true;
    _isModelLoaded = true;
    return true;
  }

  @override
  Future<List<XRexDetectedRegion>> detectObjects({
    required Uint8List imageBytes,
    required int width,
    required int height,
  }) async {
    if (!_isModelLoaded) return const [];
    return const <XRexDetectedRegion>[];
  }

  @override
  void dispose() {
    _isModelLoaded = false;
  }
}

class XRexObjectDetectionServiceStub implements XRexObjectDetectionServiceInterface {
  const XRexObjectDetectionServiceStub();

  @override
  Future<bool> loadModel({required String modelPath, int numThreads = 4}) async => true;

  @override
  Future<List<XRexDetectedRegion>> detectObjects({
    required Uint8List imageBytes,
    required int width,
    required int height,
  }) async => const <XRexDetectedRegion>[];

  @override
  void dispose() {}
}