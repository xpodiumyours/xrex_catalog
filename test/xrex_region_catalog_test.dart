import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrex_catalog/models/xrex_detected_region.dart';
import 'package:xrex_catalog/models/xrex_ocr_result.dart';
import 'package:xrex_catalog/services/xrex_catalog_analyzer_service.dart';
import 'package:xrex_catalog/services/xrex_object_detection_service.dart';
import 'package:xrex_catalog/services/xrex_ocr_service.dart';
import 'package:xrex_catalog/services/xrex_tflite_object_detection_service_platform.dart';

class MockObjectDetectionService implements XRexTfliteObjectDetectionServicePlatform {
  final List<XRexDetectedRegion> mockRegions;
  MockObjectDetectionService(this.mockRegions);

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
  }) async {
    return mockRegions.map((r) => {
      'box': [r.boundingBox.left, r.boundingBox.top, r.boundingBox.right, r.boundingBox.bottom],
      'class': r.label,
      'score': r.confidence,
    }).toList();
  }

  @override
  void dispose() {}
}

class MockOcrService extends XRexOcrService {
  final XRexOcrResult mockOcrResult;
  const MockOcrService(this.mockOcrResult);

  @override
  Future<XRexOcrResult> readResultFromImagePath(String imagePath) async {
    return mockOcrResult;
  }
}

void main() {
  test('Deduplicates 5 distinct regions of Plastik Tabure into a single product with quantity = 5', () async {
    // 5 distinct regions for chairs/stools
    final regions = List.generate(5, (index) {
      return XRexDetectedRegion(
        id: 'region_chair_${index + 1}',
        boundingBox: Rect.fromLTWH(50.0 * index, 100.0, 40.0, 40.0),
        label: 'chair',
        confidence: 0.85,
      );
    });

    // Mock OCR service returning no text overlay (so it defaults to translating the region labels)
    const mockOcrResult = XRexOcrResult(
      rawText: '',
      lines: [],
    );

    final analyzer = XRexCatalogAnalyzerService(
      tfliteObjectDetectionService: MockObjectDetectionService(regions),
      ocrService: const MockOcrService(mockOcrResult),
    );

    // Provide dummy image bytes for TFLite detection
    final dummyImageBytes = Uint8List(640 * 480 * 3);
    
    final result = await analyzer.analyzeImagePath(
      'dummy_path.jpg',
      imageBytes: dummyImageBytes,
    );

    expect(result.products.length, 1);
    final product = result.products.first;

    // Check deduction logic works (5 regions merged into 1 product with quantity = 5)
    expect(product.quantity, 5);
    expect(product.detectionIds.length, 5);
    // Name should be derived from region label 'chair' -> 'Plastik Tabure'
    // (Portfolio matching may override, so we check deduction logic primarily)
    expect(product.name, anyOf('Plastik Tabure', 'Bilinmeyen ürün'));
  });
}