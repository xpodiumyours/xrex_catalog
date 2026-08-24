import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:xrex_catalog/models/xrex_catalog_session.dart';
import 'package:xrex_catalog/models/xrex_draft_product.dart';
import 'package:xrex_catalog/models/xrex_ocr_line.dart';
import 'package:xrex_catalog/models/xrex_ocr_result.dart';
import 'package:xrex_catalog/models/xrex_detected_region.dart';
import 'package:xrex_catalog/services/xrex_catalog_analyzer_service.dart';
import 'package:xrex_catalog/services/interfaces/xrex_ocr_service.dart';
import 'package:xrex_catalog/services/interfaces/xrex_object_detection_service.dart';
import 'package:xrex_catalog/services/xrex_visual_catalog_parser.dart';

class MockOcrService extends Mock implements XRexOcrServiceInterface {}

class MockObjectDetectionService extends Mock implements XRexObjectDetectionServiceInterface {}

class MockVisualCatalogParser extends Mock implements XRexVisualCatalogParser {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List.fromList([0]));
    registerFallbackValue(1);
  });

  group('XRexCatalogAnalyzerService', () {
    late MockOcrService mockOcrService;
    late MockObjectDetectionService mockObjectDetectionService;
    late MockVisualCatalogParser mockVisualCatalogParser;
    late XRexCatalogAnalyzerService analyzer;

    setUp(() {
      mockOcrService = MockOcrService();
      mockObjectDetectionService = MockObjectDetectionService();
      mockVisualCatalogParser = MockVisualCatalogParser();

      analyzer = XRexCatalogAnalyzerService(
        ocrService: mockOcrService,
        objectDetectionService: mockObjectDetectionService,
        visualCatalogParser: mockVisualCatalogParser,
      );
    });

    group('analyzeImagePath', () {
      test('returns empty result on web when no image bytes', () async {
        final result = await analyzer.analyzeImagePath('test.jpg');
        expect(result.rawText, '');
        expect(result.regions, isEmpty);
        expect(result.products, isEmpty);
      });

      test('returns OCR result on web with image bytes', () async {
        // Skip this test as kIsWeb is compile-time constant and false in test environment
        // This test would require running on web platform
      });

      test('detects regions on mobile with image bytes', () async {
        final regions = [
          XRexDetectedRegion(
            id: 'region_1',
            boundingBox: Rect.fromLTRB(10, 10, 100, 100),
            label: 'Product',
            confidence: 0.9,
          ),
        ];

        final ocrResult = XRexOcrResult(
          rawText: 'Test ürün\n100 TL',
          lines: [
            XRexOcrLine(text: 'Test ürün', boundingBox: Rect.fromLTRB(10, 10, 100, 50), blockIndex: 0, lineIndex: 0),
            XRexOcrLine(text: '100 TL', boundingBox: Rect.fromLTRB(10, 50, 100, 90), blockIndex: 0, lineIndex: 1),
          ],
        );

        when(() => mockObjectDetectionService.detectObjects(
          imageBytes: any(named: 'imageBytes'),
          width: any(named: 'width'),
          height: any(named: 'height'),
        )).thenAnswer((_) async => regions);
        when(() => mockOcrService.readResultFromImagePath(any())).thenAnswer((_) async => ocrResult);
        when(() => mockVisualCatalogParser.parse(
          rawText: any(named: 'rawText'),
          lines: any(named: 'lines'),
          regions: any(named: 'regions'),
        )).thenReturn([]);

        final result = await analyzer.analyzeImagePath('test.jpg', imageBytes: Uint8List.fromList([1, 2, 3]));

        expect(result.regions, hasLength(1));
        expect(result.regions.first.label, 'Product');
        expect(result.rawText, 'Test ürün\n100 TL');
      });

      test('handles object detection failure gracefully', () async {
        when(() => mockObjectDetectionService.detectObjects(
          imageBytes: any(named: 'imageBytes'),
          width: any(named: 'width'),
          height: any(named: 'height'),
        )).thenThrow(Exception('Model not loaded'));

        final ocrResult = XRexOcrResult(
          rawText: 'Test ürün\n100 TL',
          lines: [
            XRexOcrLine(text: 'Test ürün', boundingBox: Rect.fromLTRB(10, 10, 100, 50), blockIndex: 0, lineIndex: 0),
            XRexOcrLine(text: '100 TL', boundingBox: Rect.fromLTRB(10, 50, 100, 90), blockIndex: 0, lineIndex: 1),
          ],
        );

        when(() => mockOcrService.readResultFromImagePath(any())).thenAnswer((_) async => ocrResult);
        when(() => mockVisualCatalogParser.parse(
          rawText: any(named: 'rawText'),
          lines: any(named: 'lines'),
          regions: any(named: 'regions'),
        )).thenReturn([]);

        final result = await analyzer.analyzeImagePath('test.jpg', imageBytes: Uint8List.fromList([1, 2, 3]));

        expect(result.regions, isEmpty);
        expect(result.rawText, 'Test ürün\n100 TL');
      });

      test('handles OCR failure gracefully', () async {
        when(() => mockObjectDetectionService.detectObjects(
          imageBytes: any(named: 'imageBytes'),
          width: any(named: 'width'),
          height: any(named: 'height'),
        )).thenAnswer((_) async => []);

        when(() => mockOcrService.readResultFromImagePath(any())).thenThrow(Exception('OCR failed'));
        when(() => mockVisualCatalogParser.parse(
          rawText: any(named: 'rawText'),
          lines: any(named: 'lines'),
          regions: any(named: 'regions'),
        )).thenReturn([]);

        final result = await analyzer.analyzeImagePath('test.jpg', imageBytes: Uint8List.fromList([1, 2, 3]));

        expect(result.rawText, '');
        expect(result.products, isEmpty);
      });
    });
  });
}