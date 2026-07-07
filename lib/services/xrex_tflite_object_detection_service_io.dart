import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/xrex_detected_region.dart';

class XRexTfliteObjectDetectionService {
  static const String _modelAsset = 'assets/ml/efficientdet_lite0.tflite';

  const XRexTfliteObjectDetectionService({
    this.scoreThreshold = 0.40,
    this.maxResults = 12,
  });

  final double scoreThreshold;
  final int maxResults;

  Future<List<XRexDetectedRegion>> detectObjectsFromImageBytes(
    Uint8List imageBytes,
  ) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return const [];

    final interpreter = await Interpreter.fromAsset(_modelAsset);
    try {
      final inputTensor = interpreter.getInputTensor(0);
      final inputShape = inputTensor.shape;
      if (inputShape.length != 4) return const [];

      final inputHeight = inputShape[1];
      final inputWidth = inputShape[2];
      final resized = img.copyResize(
        decoded,
        width: inputWidth,
        height: inputHeight,
      );

      final input = _buildInput(resized, inputTensor);
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
    } finally {
      interpreter.close();
    }
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
}
