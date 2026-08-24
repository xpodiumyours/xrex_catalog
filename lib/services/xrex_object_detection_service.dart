import 'package:flutter/foundation.dart';
import 'dart:typed_data';

import 'xrex_tflite_object_detection_service_io.dart';
import 'xrex_tflite_object_detection_service_web.dart';
import 'xrex_tflite_object_detection_service_platform.dart';

/// Platform Bağımsız TFLite Nesne Algılama Servisi
/// Otomatik olarak uygun platform implementasyonunu kullanır (IO, Web, Stub)
class XrexTFLiteObjectDetectionService implements XRexTfliteObjectDetectionServicePlatform {
  static final XrexTFLiteObjectDetectionService _instance =
      XrexTFLiteObjectDetectionService._internal();

  factory XrexTFLiteObjectDetectionService() => _instance;
  XrexTFLiteObjectDetectionService._internal();

  // Platforma göre doğru servisi seç
  final XRexTfliteObjectDetectionServicePlatform _service = kIsWeb
      ? XRexTfliteObjectDetectionServiceWeb()
      : XRexTfliteObjectDetectionServiceIO();

  @override
  /// Modeli yükle
  Future<bool> loadModel({
    required String modelPath,
    int numThreads = 4,
  }) async {
    return await _service.loadModel(
      modelPath: modelPath,
      numThreads: numThreads,
    );
  }

  @override
  /// Nesne tespiti yap
  Future<List<Map<String, dynamic>>?> detectObjects({
    required Uint8List imageBytes,
    required int width,
    required int height,
  }) async {
    return await _service.detectObjects(
      imageBytes: imageBytes,
      width: width,
      height: height,
    );
  }

  @override
  /// Kaynakları temizle
  void dispose() {
    _service.dispose();
  }
}