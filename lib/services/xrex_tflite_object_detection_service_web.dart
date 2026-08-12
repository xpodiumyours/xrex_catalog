import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tflite_web/tflite_web.dart';
import 'package:tflite_web_api/tflite_web_api.dart';

/// Web platformu için Nesne Algılama Servisi
/// Tarayıcıda TensorFlow.js benzeri TFLite Web API kullanır.
class XrexObjectDetectionServiceWeb {
  static final XrexObjectDetectionServiceWeb _instance =
      XrexObjectDetectionServiceWeb._internal();
  factory XrexObjectDetectionServiceWeb() => _instance;
  XrexObjectDetectionServiceWeb._internal();

  TFLiteWebModelRunner? _modelRunner;
  bool _isModelLoaded = false;

  /// Modeli yükle
  Future<bool> loadModel({
    required String modelPath,
    required int numThreads = 4, // Web'de thread sayısı WebGL bağlamına bağlıdır
  }) async {
    if (_isModelLoaded) return true;

    try {
      // TFLite Web API kullanarak modeli yükle
      // Not: Web'de model yolu asset olarak değil, URL olarak çözülür.
      final modelOptions = TFLiteWebModelRunnerOptions(
        modelAssetPath: modelPath,
        numThreads: numThreads,
      );

      _modelRunner = await TFLiteWebModelRunner.create(options: modelOptions);
      _isModelLoaded = true;
      debugPrint('[Xrex Web] Model başarıyla yüklendi: $modelPath');
      return true;
    } catch (e) {
      debugPrint('[Xrex Web] Model yükleme hatası: $e');
      return false;
    }
  }

  /// Görüntüyü analiz et
  /// [imageBytes]: Uint8List formatında resim verisi
  /// [width], [height]: Resim boyutları
  Future<List<Map<String, dynamic>>?> detectObjects({
    required Uint8List imageBytes,
    required int width,
    required int height,
  }) async {
    if (!_isModelLoaded || _modelRunner == null) {
      debugPrint('[Xrex Web] Model henüz yüklenmedi.');
      return null;
    }

    try {
      // Web için input tensor hazırlığı
      // TFLite Web API genellikle normalize edilmiş float32 bekler (0.0 - 1.0)
      // veya model konfigürasyonuna göre uint8. Burada genel bir yaklaşım sunulmuştur.
      
      final inputs = _modelRunner!.getInputs();
      final outputs = _modelRunner!.getOutputs();

      // Input tensor boyutlarını al (Genelde [1, height, width, 3])
      final inputShape = inputs[0].shape; 
      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];

      // Görüntüyü modele uygun boyuta getir ve normalize et
      // Not: Gerçek uygulamada burada canvas çizimi ile resize işlemi yapılmalı
      final inputData = await _processImageForWeb(imageBytes, width, height, inputWidth, inputHeight);

      // Veriyi input tensor'a yaz
      inputs[0].data.asFloat32List().setAll(0, inputData);

      // Çıkarım yap (Invoke)
      await _modelRunner!.invoke();

      // Çıktıları yorumla
      final outputData = outputs[0].data.asFloat32List();
      
      return _parseOutput(outputData, width, height);

    } catch (e) {
      debugPrint('[Xrex Web] Tespit hatası: $e');
      return null;
    }
  }

  /// Resmi işle ve normalize et (0.0 - 1.0 arası)
  Future<Float32List> _processImageForWeb(
    Uint8List imageBytes, 
    int origWidth, 
    int origHeight, 
    int targetWidth, 
    int targetHeight
  ) async {
    // Web'de resim işleme için HTML Canvas kullanılabilir veya
    // basitçe byte dizisi üzerinde işlem yapılabilir.
    // Performans için basit bir resize ve normalize örneği:
    
    // NOT: Production kodunda burada 'html' paketi ile Canvas çizimi yapılıp
    // getImageData ile pixel pixel okuma en sağlıklısıdır.
    // Şimdilik basitlik adına girdiyi olduğu gibi kabul edip normalize ettiğimizi varsayıyoruz
    // ancak gerçek senaryoda resize şarttır.
    
    final normalizedData = Float32List(targetHeight * targetWidth * 3);
    
    // Basit bir resize mantığı (Bilinear Interpolation yerine nearest neighbor örneği)
    // Gerçek implementasyonda html.Canvas kullanılması şiddetle önerilir.
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        final srcX = (x * origWidth / targetWidth).floor();
        final srcY = (y * origHeight / targetHeight).floor();
        
        final srcIndex = (srcY * origWidth + srcX) * 3;
        final dstIndex = (y * targetWidth + x) * 3;

        if (srcIndex + 2 < imageBytes.length) {
          normalizedData[dstIndex] = imageBytes[srcIndex] / 255.0;     // R
          normalizedData[dstIndex + 1] = imageBytes[srcIndex + 1] / 255.0; // G
          normalizedData[dstIndex + 2] = imageBytes[srcIndex + 2] / 255.0; // B
        }
      }
    }
    
    return normalizedData;
  }

  /// Model çıktısını (Bounding Box, Class, Score) parse et
  List<Map<String, dynamic>> _parseOutput(Float32List outputData, int imgW, int imgH) {
    final results = <Map<String, dynamic>>[];
    
    // SSD MobileNet V2 gibi modellerin çıktı formatı örneği:
    // [num_detections, detection_boxes, detection_classes, detection_scores]
    // Bu kısım modelinize göre değişmelidir.
    
    // Örnek bir döngü (Model çıktı shape'ine göre düzenlenmeli)
    // Genelde outputData düz bir listedir, shape'e göre ayrıştırılır.
    
    /* 
    Örnek Mantık:
    for (var i = 0; i < numDetections; i++) {
      var score = outputData[i];
      if (score > threshold) {
        var box = [...];
        results.add({
          'box': box,
          'class': className,
          'score': score,
        });
      }
    }
    */
   
    // Şimdilik boş dönüyor, model shape'ine göre doldurulacak.
    return results;
  }

  void dispose() {
    _modelRunner?.dispose();
    _isModelLoaded = false;
  }
}
