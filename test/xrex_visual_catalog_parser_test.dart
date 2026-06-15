import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrex_catalog/models/xrex_ocr_line.dart';
import 'package:xrex_catalog/services/xrex_visual_catalog_parser.dart';

void main() {
  const parser = XRexVisualCatalogParser();

  XRexOcrLine line(
    String text,
    double left,
    double top,
    double right,
    double bottom, {
    int index = 0,
  }) {
    return XRexOcrLine(
      text: text,
      boundingBox: Rect.fromLTRB(left, top, right, bottom),
      blockIndex: index,
      lineIndex: index,
    );
  }

  group('Original Parser Tests', () {
    test('groups marketplace-like OCR lines into product cards', () {
      final products = parser.parse(
        rawText: '',
        lines: [
          line('Ana Sayfa', 20, 120, 130, 150, index: 1),
          line('OFİS Klas müdür koltuğu', 30, 470, 245, 505, index: 2),
          line('Hızlı teslimat yapılıyor!', 30, 520, 230, 545, index: 3),
          line('Kargo Bedava', 30, 555, 150, 580, index: 4),
          line('Sepette 4.000 TL', 30, 600, 180, 630, index: 5),
          line('5.000 TL', 30, 635, 130, 660, index: 6),
          line('Masa sandalye takımı', 310, 470, 520, 505, index: 7),
          line('Kargo Bedava', 310, 555, 450, 580, index: 8),
          line('5.500 TL', 310, 600, 430, 630, index: 9),
        ],
      );

      expect(products, hasLength(2));
      expect(products.first.name, 'OFİS Klas müdür koltuğu');
      expect(products.first.price, contains('4.000'));
      expect(products.first.oldPrice, '5.000 TL');
      expect(products.first.category, 'Mobilya');
      expect(products.first.sourceRect, isNotNull);
      expect(products.first.origin, 'visual_ocr');
      expect(products[1].name, 'Masa sandalye takımı');
    });

    test('filters UI noise and does not use it as product name', () {
      final products = parser.parse(
        rawText: '',
        lines: [
          line('Mağazada ara', 20, 80, 200, 115, index: 1),
          line('Favoriler', 220, 80, 320, 115, index: 2),
          line('QBC ofis büro çalışma koltuğu', 30, 430, 260, 465, index: 3),
          line('4.6 ★★★★★ (84)', 30, 490, 180, 520, index: 4),
          line('Kargo Bedava', 30, 525, 165, 550, index: 5),
          line('2.320 TL', 30, 580, 150, 610, index: 6),
        ],
      );

      expect(products, hasLength(1));
      expect(products.first.name, 'QBC ofis büro çalışma koltuğu');
      expect(products.first.price, '2.320 TL');
      expect(products.first.category, 'Mobilya');
    });

    test('falls back to raw text parser when OCR coordinates are missing', () {
      final products = parser.parse(
        rawText: 'Penti çorap\n175 TL',
        lines: const [],
      );

      expect(products, hasLength(1));
      expect(products.first.name, 'Penti çorap');
      expect(products.first.price, '175 TL');
      expect(products.first.category, 'Giyim');
    });
  });

  group('OCR Fixture cases', () {
    void runFixtureTest(String fileName) {
      final file = File('test/fixtures/ocr_cases/$fileName');
      expect(file.existsSync(), isTrue, reason: 'Fixture file $fileName must exist');
      
      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final rawText = json['rawText'] as String;
      final linesJson = json['lines'] as List<dynamic>;
      final lines = linesJson.map((x) => XRexOcrLine.fromJson(x as Map<String, dynamic>)).toList();

      final parsedProducts = parser.parse(
        rawText: rawText,
        lines: lines,
      );

      final expectedProductsJson = json['expectedProducts'] as List<dynamic>;
      expect(parsedProducts.length, expectedProductsJson.length, 
          reason: 'Expected ${expectedProductsJson.length} products, but got ${parsedProducts.length} in $fileName');

      for (var i = 0; i < parsedProducts.length; i++) {
        final parsed = parsedProducts[i];
        final expected = expectedProductsJson[i] as Map<String, dynamic>;

        expect(parsed.name, contains(expected['name'] as String), 
            reason: 'Product name mismatch at index $i in $fileName');
        expect(parsed.price, expected['price'] as String, 
            reason: 'Product price mismatch at index $i in $fileName');
        expect(parsed.priceAmount, expected['priceAmount'] as double?, 
            reason: 'Product priceAmount mismatch at index $i in $fileName');
        expect(parsed.category, expected['category'] as String, 
            reason: 'Product category mismatch at index $i in $fileName');
      }

      if (json.containsKey('expectedCategory')) {
        final overallCategory = json['expectedCategory'] as String;
        expect(parsedProducts.any((p) => p.category == overallCategory), isTrue,
            reason: 'At least one product should have category $overallCategory in $fileName');
      }
    }

    test('Case 1: two_column_screenshot', () {
      runFixtureTest('two_column_screenshot.json');
    });

    test('Case 2: store_front_multi_product', () {
      runFixtureTest('store_front_multi_product.json');
    });

    test('Case 3: name_above_price', () {
      runFixtureTest('name_above_price.json');
    });

    test('Case 4: name_on_same_line', () {
      runFixtureTest('name_on_same_line.json');
    });

    test('Case 5: noisy_screen', () {
      runFixtureTest('noisy_screen.json');
    });
  });

  group('Refined Noise and Candidate Tests', () {
    test('does not produce 15 products for 4 products on a noisy screen', () {
      final products = parser.parse(
        rawText: '',
        lines: [
          // Row 1 - Product 1
          line('Pamuklu Tişört', 30, 200, 200, 230, index: 1),
          line('350 TL', 30, 240, 150, 270, index: 2),
          // Row 1 - Product 2
          line('Keten Şort', 300, 200, 450, 230, index: 3),
          line('450 TL', 300, 240, 400, 270, index: 4),
          // Row 2 - Product 3
          line('Spor Ayakkabı', 30, 500, 200, 530, index: 5),
          line('1.200 TL', 30, 540, 150, 570, index: 6),
          // Row 2 - Product 4
          line('Güneş Gözlüğü', 300, 500, 450, 530, index: 7),
          line('800 TL', 300, 540, 400, 570, index: 8),

          // Noisy lines (should be filtered out or put in candidates if they are names/prices, but filtered if pure noise)
          line('Kargo Bedava', 30, 280, 120, 300, index: 9), // noise
          line('Kupon 50 TL', 300, 280, 420, 300, index: 10), // noise
          line('4.9 (150 yorum)', 30, 310, 160, 330, index: 11), // noise
          line('1', 200, 20, 220, 40, index: 12), // noise (single digit)
          line(r'$', 10, 800, 30, 820, index: 13), // noise (symbol)
          line('free shipping details', 50, 900, 250, 920, index: 14), // noise (english words)
          
          // An unpaired candidate line (not noise, e.g. "Kırmızı Ceket" but no price)
          line('Kırmızı Ceket', 500, 200, 650, 230, index: 15), // candidate
        ],
      );

      // We should detect exactly 4 ready products and 1 candidate (Kırmızı Ceket).
      // The total product count must not be 15!
      expect(products.length, lessThan(10));
      
      final readyProducts = products.where((p) => p.confidence! >= 0.8).toList();
      final candidates = products.where((p) => p.confidence! < 0.8).toList();

      expect(readyProducts.length, 4);
      expect(candidates.length, 2);
      expect(candidates.any((p) => p.name == 'Kırmızı Ceket'), isTrue);
    });
  });
}
