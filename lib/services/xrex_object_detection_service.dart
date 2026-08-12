import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'xrex_tflite_object_detection_service_io.dart'
    if (dart.library.html) 'xrex_tflite_object_detection_service_web.dart';

/// Platform Bağımsız TFLite Nesne Algılama Servisi
/// Otomatik olarak IO (Mobil/Desktop) veya Web implementasyonunu seçer.
class XrexTFLiteObjectDetectionService {
  static final XrexTFLiteObjectDetectionService _instance =
      XrexTFLiteObjectDetectionService._internal();
  
  factory XrexTFLiteObjectDetectionService() => _instance;
  XrexTFLiteObjectDetectionService._internal();

  // Platforma göre doğru servisi seç
  final _service = kIsWeb
      ? XrexObjectDetectionServiceWeb()
      : XrexObjectDetectionServiceIO();

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

  /// Kaynakları temizle
  void dispose() {
    _service.dispose();
  }
}
