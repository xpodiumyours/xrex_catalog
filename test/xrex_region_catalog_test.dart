import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrex_catalog/models/xrex_detected_region.dart';
import 'package:xrex_catalog/models/xrex_ocr_result.dart';
import 'package:xrex_catalog/services/xrex_catalog_analyzer_service.dart';
import 'package:xrex_catalog/services/xrex_object_detection_service.dart';
import 'package:xrex_catalog/services/xrex_ocr_service.dart';

class MockObjectDetectionService extends XRexObjectDetectionService {
  final List<XRexDetectedRegion> mockRegions;
  const MockObjectDetectionService(this.mockRegions);

  @override
  Future<List<XRexDetectedRegion>> detectObjectsFromImagePath(String imagePath) async {
    return mockRegions;
  }
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
      objectDetectionService: MockObjectDetectionService(regions),
      ocrService: const MockOcrService(mockOcrResult),
    );

    final result = await analyzer.analyzeImagePath('dummy_path.jpg');

    expect(result.products.length, 1);
    final product = result.products.first;

    expect(product.name, 'Plastik Tabure');
    expect(product.quantity, 5);
    expect(product.detectionIds.length, 5);
    expect(
      product.detectionIds,
      containsAll([
        'region_chair_1',
        'region_chair_2',
        'region_chair_3',
        'region_chair_4',
        'region_chair_5',
      ]),
    );
  });
}
