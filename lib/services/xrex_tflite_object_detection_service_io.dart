import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/xrex_detected_region.dart';
import 'xrex_tflite_object_detection_service_platform.dart';

/// XRex TFLite Nesne Algılama Servisi (Geliştirilmiş) - IO Platformu
/// - INT8 kuantizasyon desteği
/// - Dinamik çözünürlük ayarı
/// - Gelişmiş ön işleme entegrasyonu
class XRexTfliteObjectDetectionServiceIO implements XRexTfliteObjectDetectionServicePlatform {
  static const String _modelAssetFloat = 'assets/ml/efficientdet_lite0.tflite';
  static const String _modelAssetInt8 = 'assets/ml/efficientdet_lite0_int8.tflite';

  const XRexTfliteObjectDetectionServiceIO({
    this.scoreThreshold = 0.40,
    this.maxResults = 12,
    this.useQuantizedModel = true,
    this.dynamicResolution = true,
  });

  final double scoreThreshold;
  final int maxResults;
  final bool useQuantizedModel;
  final bool dynamicResolution;

  @override
  Future<bool> loadModel({
    required String modelPath,
    int numThreads = 4,
  }) async {
    // IO platformunda model loadModel çağrısıyla değil, detectObjectsFromImageBytes içinde yüklenir
    return true;
  }

  @override
  /// Nesne tespiti yap (IO platformu için wrapper)
  Future<List<Map<String, dynamic>>?> detectObjects({
    required Uint8List imageBytes,
    required int width,
    required int height,
  }) async {
    final regions = await detectObjectsFromImageBytes(imageBytes);
    return regions.map((r) => {
      'box': [r.boundingBox.left, r.boundingBox.top, r.boundingBox.right, r.boundingBox.bottom],
      'class': r.label,
      'score': r.confidence,
    }).toList();
  }

  /// Görsel bytes'ından nesne algılama işlemi yapar
  Future<List<XRexDetectedRegion>> detectObjectsFromImageBytes(
    Uint8List imageBytes,
  ) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return const [];

    // Dinamik çözünürlük ayarı
    final targetSize = _calculateOptimalInputSize(decoded);
    final resized = img.copyResize(
      decoded,
      width: targetSize.width.round(),
      height: targetSize.height.round(),
    );

    // Model seçimi (INT8 veya Float32)
    final modelAsset = useQuantizedModel ? _modelAssetInt8 : _modelAssetFloat;
    
    Interpreter? interpreter;
    try {
      interpreter = await Interpreter.fromAsset(modelAsset);
      
      final inputTensor = interpreter.getInputTensor(0);
      final inputShape = inputTensor.shape;
      if (inputShape.length != 4) return const [];

      final inputHeight = (inputShape[1] as int?) ?? 320;
      final inputWidth = (inputShape[2] as int?) ?? 320;
      
      // Hızlı yeniden boyutlandırma (zaten yapıldı ama kontrol)
      final finalResized = resized.width != inputWidth || resized.height != inputHeight
          ? img.copyResize(resized, width: inputWidth, height: inputHeight)
          : resized;

      final input = _buildInput(finalResized, inputTensor);
      final outputTensors = interpreter.getOutputTensors();
      final outputs = <int, Object>{};

      for (var i = 0; i < outputTensors.length; i += 1) {
        outputs[i] = _emptyOutput(outputTensors[i]);
      }

      interpreter.runForMultipleInputs([input], outputs);

      final parsed = _parseOutputs(
        outputTensors: outputTensors,
        outputs: outputs,
        imageWidth: decoded.width.toDouble(),
        imageHeight: decoded.height.toDouble(),
      );

      return _dedupeRegions(parsed).take(maxResults).toList(growable: false);
    } catch (e) {
      // INT8 modeli bulunamazsa float modele geç
      if (useQuantizedModel && e.toString().contains('asset')) {
        return XRexTfliteObjectDetectionServiceIO(
          scoreThreshold: scoreThreshold,
          maxResults: maxResults,
          useQuantizedModel: false,
          dynamicResolution: dynamicResolution,
        ).detectObjectsFromImageBytes(imageBytes);
      }
      rethrow;
    } finally {
      interpreter?.close();
    }
  }

  /// Görselin karmaşıklığına göre optimal giriş boyutunu hesaplar
  Size _calculateOptimalInputSize(img.Image image) {
    if (!dynamicResolution) {
      return const Size(320, 320); // Varsayılan boyut
    }

    // Basit karmaşıklık metrikleri
    final avgBrightness = _calculateAverageBrightness(image);
    final edgeDensity = _calculateEdgeDensity(image);
    
    // Düşük ışık veya yüksek kenar yoğunluğu -> Daha yüksek çözünürlük
    if (avgBrightness < 80 || edgeDensity > 0.3) {
      return const Size(512, 512);
    } else if (avgBrightness < 120 || edgeDensity > 0.2) {
      return const Size(384, 384);
    }
    
    return const Size(320, 320);
  }

  /// Ortalama parlaklık hesaplama
  double _calculateAverageBrightness(img.Image image) {
    int totalLuminance = 0;
    int pixelCount = 0;
    final step = math.max(1, (image.width ~/ 50)); // Performans için örnekleme
    
    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        final pixel = image.getPixel(x, y);
        // İnsan gözü yeşile daha duyarlı
        totalLuminance += (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114).round();
        pixelCount++;
      }
    }
    
    return pixelCount > 0 ? totalLuminance / pixelCount : 128;
  }

  /// Kenar yoğunluğu hesaplama (basit Sobel operatörü)
  double _calculateEdgeDensity(img.Image image) {
    final grayscale = img.grayscale(image);
    int edgePixels = 0;
    int totalPixels = 0;
    final step = math.max(1, (image.width ~/ 30));
    
    for (int y = 1; y < image.height - 1; y += step) {
      for (int x = 1; x < image.width - 1; x += step) {
        final center = grayscale.getPixel(x, y).r.toInt();
        final left = grayscale.getPixel(x - 1, y).r.toInt();
        final right = grayscale.getPixel(x + 1, y).r.toInt();
        final top = grayscale.getPixel(x, y - 1).r.toInt();
        final bottom = grayscale.getPixel(x, y + 1).r.toInt();
        
        final gradientX = (right - left).abs();
        final gradientY = (bottom - top).abs();
        final gradient = gradientX + gradientY;
        
        if (gradient > 50) { // Eşik değeri
          edgePixels++;
        }
        totalPixels++;
      }
    }
    
    return totalPixels > 0 ? edgePixels / totalPixels : 0.0;
  }

  Object _buildInput(img.Image resized, Tensor inputTensor) {
    final isFloat = inputTensor.type.toString().toLowerCase().contains('float');

    return [
      List.generate(resized.height, (y) {
        return List.generate(resized.width, (x) {
          final pixel = resized.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();

          if (isFloat) {
            return [r / 255.0, g / 255.0, b / 255.0];
          }
          return [r.toInt(), g.toInt(), b.toInt()];
        });
      }),
    ];
  }

  Object _emptyOutput(Tensor tensor) {
    final shape = tensor.shape;
    final isInteger = _isIntegerType(tensor);

    Object fill(List<int> dims) {
      if (dims.length == 1) {
        return List.filled(dims[0], isInteger ? 0 : 0.0);
      }
      return List.generate(dims[0], (_) => fill(dims.sublist(1)));
    }

    return fill(shape);
  }

  List<XRexDetectedRegion> _parseOutputs({
    required List<Tensor> outputTensors,
    required Map<int, Object> outputs,
    required double imageWidth,
    required double imageHeight,
  }) {
    Object? boxes;
    Object? classes;
    Object? scores;
    Object? count;
    final twoDimensional = <Object>[];

    for (var i = 0; i < outputTensors.length; i += 1) {
      final tensor = outputTensors[i];
      final value = outputs[i];
      final shape = tensor.shape;
      final name = tensor.name.toLowerCase();

      if (shape.length == 3 && shape.last == 4) {
        boxes = value;
      } else if (shape.length == 1) {
        count = value;
      } else if (shape.length == 2) {
        if (name.contains('score')) {
          scores = value;
        } else if (name.contains('class')) {
          classes = value;
        } else if (value != null) {
          twoDimensional.add(value);
        }
      }
    }

    if (classes == null && twoDimensional.isNotEmpty) {
      classes = twoDimensional.first;
    }
    if (scores == null && twoDimensional.length > 1) {
      scores = twoDimensional[1];
    }

    if (boxes == null || scores == null) return const [];

    final boxRows = _firstBatch(boxes);
    final scoreRows = _firstBatch(scores);
    final classRows = classes == null ? const <Object>[] : _firstBatch(classes);
    final detectedCount = math.min(
      _readCount(count, scoreRows.length),
      scoreRows.length,
    );

    final regions = <XRexDetectedRegion>[];
    for (var i = 0; i < detectedCount; i += 1) {
      final score = _toDouble(scoreRows[i]);
      if (score < scoreThreshold) continue;

      final box = _asList(boxRows[i]);
      if (box.length < 4) continue;

      final top = _clamp01(_toDouble(box[0])) * imageHeight;
      final left = _clamp01(_toDouble(box[1])) * imageWidth;
      final bottom = _clamp01(_toDouble(box[2])) * imageHeight;
      final right = _clamp01(_toDouble(box[3])) * imageWidth;
      if ((right - left) < 8 || (bottom - top) < 8) continue;

      final classId =
          i < classRows.length ? _toDouble(classRows[i]).round() : null;

      regions.add(
        XRexDetectedRegion(
          id: 'tflite_region_${regions.length + 1}',
          boundingBox: Rect.fromLTRB(left, top, right, bottom),
          label: classId == null ? 'TFLite ürün' : 'TFLite sınıf $classId',
          confidence: score,
        ),
      );
    }

    regions.sort((a, b) => (b.confidence ?? 0).compareTo(a.confidence ?? 0));
    return regions;
  }

  List<XRexDetectedRegion> _dedupeRegions(List<XRexDetectedRegion> regions) {
    final accepted = <XRexDetectedRegion>[];
    for (final region in regions) {
      final overlaps = accepted.any(
        (existing) => _iou(existing.boundingBox, region.boundingBox) > 0.72,
      );
      if (!overlaps) accepted.add(region);
    }
    return accepted;
  }

  bool _isIntegerType(Tensor tensor) {
    final type = tensor.type.toString().toLowerCase();
    return type.contains('int') || type.contains('uint');
  }

  List<Object> _firstBatch(Object value) {
    final list = _asList(value);
    if (list.isEmpty) return const [];
    final first = list.first;
    if (first is List) return first.cast<Object>();
    return list;
  }

  List<Object> _asList(Object? value) {
    if (value is List) return value.cast<Object>();
    return const [];
  }

  int _readCount(Object? value, int fallback) {
    final list = _asList(value);
    if (list.isEmpty) return fallback;
    final count = _toDouble(list.first).round();
    return count <= 0 ? fallback : math.min(count, fallback);
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return 0;
  }

  double _clamp01(double value) => value.clamp(0.0, 1.0);

  double _iou(Rect a, Rect b) {
    final left = math.max(a.left, b.left);
    final top = math.max(a.top, b.top);
    final right = math.min(a.right, b.right);
    final bottom = math.min(a.bottom, b.bottom);
    final intersection =
        math.max(0.0, right - left) * math.max(0.0, bottom - top);
    if (intersection <= 0) return 0;

    final union = a.width * a.height + b.width * b.height - intersection;
    if (union <= 0) return 0;
    return intersection / union;
  }

  @override
  void dispose() {
    // IO platform doesn't hold persistent resources
  }
}
