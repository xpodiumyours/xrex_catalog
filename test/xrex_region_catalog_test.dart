import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrex_catalog/models/xrex_detected_region.dart';
import 'package:xrex_catalog/models/xrex_ocr_result.dart';
import 'package:xrex_catalog/services/xrex_catalog_analyzer_service.dart';
import 'package:xrex_catalog/services/interfaces/xrex_object_detection_service.dart';
import 'package:xrex_catalog/services/interfaces/xrex_ocr_service.dart';

class MockObjectDetectionService implements XRexObjectDetectionServiceInterface {
  final List<XRexDetectedRegion> mockRegions;
  MockObjectDetectionService(this.mockRegions);

  @override
  Future<bool> loadModel({
    required String modelPath,
    int numThreads = 4,
  }) async => true;

  @override
  Future<List<XRexDetectedRegion>> detectObjects({
    required Uint8List imageBytes,
    required int width,
    required int height,
  }) async => mockRegions;

  @override
  void dispose() {}
}

class MockOcrService implements XRexOcrServiceInterface {
  final XRexOcrResult mockOcrResult;
  const MockOcrService(this.mockOcrResult);

  @override
  Future<String> readTextFromImagePath(String imagePath) async {
    return mockOcrResult.rawText;
  }

  @override
  Future<XRexOcrResult> readResultFromImagePath(String imagePath) async {
    return mockOcrResult;
  }

  @override
  Future<XRexOcrResult> readResultFromImageBytes(Uint8List bytes) async {
    return mockOcrResult;
  }
}

void main() {
  test('Deduplicates 5 distinct regions of Plastik Tabure into a single product with quantity = 5', () async {
    final regions = List.generate(5, (index) {
      return XRexDetectedRegion(
        id: 'region_chair_${index + 1}',
        boundingBox: Rect.fromLTWH(50.0 * index, 100.0, 40.0, 40.0),
        label: 'chair',
        confidence: 0.85,
      );
    });

    const mockOcrResult = XRexOcrResult(
      rawText: '',
      lines: [],
    );

    final analyzer = XRexCatalogAnalyzerService(
      objectDetectionService: MockObjectDetectionService(regions),
      ocrService: MockOcrService(mockOcrResult),
    );

    final dummyImageBytes = Uint8List(640 * 480 * 3);
    
    final result = await analyzer.analyzeImagePath(
      'dummy_path.jpg',
      imageBytes: dummyImageBytes,
    );

    expect(result.products.length, 1);
    final product = result.products.first;

    expect(product.quantity, 5);
    expect(product.detectionIds.length, 5);
    expect(product.name, anyOf('Plastik Tabure', 'Bilinmeyen ürün'));
  });
}