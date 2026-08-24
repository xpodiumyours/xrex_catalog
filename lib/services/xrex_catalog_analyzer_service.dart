// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../models/xrex_detected_region.dart';
import '../models/xrex_draft_product.dart';
import '../models/xrex_ocr_line.dart';
import '../models/xrex_ocr_result.dart';
import 'xrex_product_text_normalizer.dart';
import 'xrex_visual_catalog_parser.dart';
import 'xrex_portfolio_service.dart';
import 'xrex_price_parser.dart';
import 'interfaces/xrex_ocr_service.dart';
import 'interfaces/xrex_object_detection_service.dart';
import 'xrex_ocr_service.dart';
import 'xrex_object_detection_service.dart';

class XRexCatalogAnalysisResult {
  final String rawText;
  final List<XRexDetectedRegion> regions;
  final List<XRexDraftProduct> products;

  const XRexCatalogAnalysisResult({
    required this.rawText,
    required this.regions,
    required this.products,
  });
}

class XRexCatalogAnalyzerService {
  final XRexOcrServiceInterface ocrService;
  final XRexObjectDetectionServiceInterface objectDetectionService;
  final XRexVisualCatalogParser visualCatalogParser;

  XRexCatalogAnalyzerService({
    XRexObjectDetectionServiceInterface? objectDetectionService,
    XRexOcrServiceInterface? ocrService,
    XRexVisualCatalogParser? visualCatalogParser,
  }) : objectDetectionService = objectDetectionService ?? const XRexTfliteObjectDetectionService(),
       ocrService = ocrService ?? const XRexOcrService(),
       visualCatalogParser = visualCatalogParser ?? const XRexVisualCatalogParser();

  Future<XRexCatalogAnalysisResult> analyzeImagePath(
    String imagePath, {
    Uint8List? imageBytes,
  }) async {
    final XRexOcrResult ocrResult;
    final List<XRexDetectedRegion> regions;

    if (kIsWeb) {
      if (imageBytes != null && imageBytes.isNotEmpty) {
        ocrResult = await ocrService.readResultFromImageBytes(imageBytes);
      } else {
        ocrResult = XRexOcrResult.empty;
      }
      regions = const [];
    } else {
      regions = await _detectRegions(imagePath, imageBytes: imageBytes);
      ocrResult = await _readOcrSafely(imagePath);
    }

    final products = _mergeRegionsAndText(regions, ocrResult.lines);

    return XRexCatalogAnalysisResult(
      rawText: ocrResult.rawText,
      regions: regions,
      products: products,
    );
  }

  Future<List<XRexDetectedRegion>> _detectRegions(
    String imagePath, {
    Uint8List? imageBytes,
  }) async {
    if (imageBytes != null && imageBytes.isNotEmpty) {
      try {
        final detectedRegions = await objectDetectionService.detectObjects(
          imageBytes: imageBytes,
          width: 640,
          height: 480,
        );
        if (detectedRegions.isNotEmpty) {
          return detectedRegions;
        }
      } catch (_) {
        // Object detection failed, return empty
      }
    }
    return const [];
  }

  Future<XRexOcrResult> _readOcrSafely(String imagePath) async {
    try {
      return ocrService.readResultFromImagePath(imagePath);
    } catch (_) {
      return XRexOcrResult.empty;
    }
  }

  List<XRexDraftProduct> _mergeRegionsAndText(
    List<XRexDetectedRegion> regions,
    List<XRexOcrLine> ocrLines,
  ) {
    final rawProducts = <XRexDraftProduct>[];
    final usedOcrKeys = <String>{};

    for (var i = 0; i < regions.length; i++) {
      final region = regions[i];
      final regionId = region.id;

      final matchedOcr =
          ocrLines.where((line) {
            final lineBox = line.boundingBox;
            final overlap = _horizontalOverlap(region.boundingBox, lineBox);
            if (overlap <= 0) return false;

            final isInside =
                lineBox.top >= region.boundingBox.top - 50 &&
                lineBox.bottom <= region.boundingBox.bottom + 150;

            final hDist = (line.centerX - region.centerX).abs();
            final isHorizontallyAligned =
                hDist < region.boundingBox.width * 0.7;

            return isInside && isHorizontallyAligned;
          }).toList();

      for (final line in matchedOcr) {
        usedOcrKeys.add('${line.blockIndex}:${line.lineIndex}');
      }

      final parsedList = visualCatalogParser.parse(
        rawText: '',
        lines: matchedOcr,
      );

      if (parsedList.isNotEmpty) {
        for (final parsed in parsedList) {
          final cleanName = XRexProductTextNormalizer.normalizeProductName(
            parsed.name,
          );
          rawProducts.add(
            XRexDraftProduct(
              id:
                  '${DateTime.now().microsecondsSinceEpoch}_r_${i}_${rawProducts.length}',
              name: cleanName.isEmpty ? parsed.name : cleanName,
              price: parsed.price,
              oldPrice: parsed.oldPrice,
              description:
                  parsed.description.isNotEmpty
                      ? parsed.description
                      : 'Bölge #${i + 1} tespiti',
              category: parsed.category,
              stockStatus: 'Mevcut',
              sourceLineSummary: parsed.sourceLines.join('\n'),
              parserWarnings: parsed.warnings,
              detectionId: regionId,
              detectionIds: [regionId],
              origin: 'merged',
              confidence: parsed.confidence ?? region.confidence,
              priceAmount: parsed.priceAmount,
              sourceLines: parsed.sourceLines,
              quantity: 1,
            ),
          );
        }
      } else {
        final nonNoiseText = matchedOcr
            .where(
              (line) => line.text.trim().isNotEmpty && !_isNoiseLine(line.text),
            )
            .map((line) => line.text.trim())
            .join(' ');

        String name = '';
        if (nonNoiseText.isNotEmpty) {
          name = nonNoiseText;
        } else if (region.label != null && region.label!.isNotEmpty) {
          name = _translateLabel(region.label!);
        } else {
          name = 'G\u{00f6}rsel \u{00dc}r\u{00fc}n #${i + 1}';
        }
        final cleanName = XRexProductTextNormalizer.normalizeProductName(name);
        if (cleanName.isNotEmpty) {
          name = cleanName;
        }

        final sourceLines = matchedOcr.map((line) => line.text).toList();
        rawProducts.add(
          XRexDraftProduct(
            id:
                '${DateTime.now().microsecondsSinceEpoch}_r_${i}_${rawProducts.length}',
            name: name,
            price: '',
            oldPrice: '',
            description: 'Foto\u{011f}raftan ${region.label ?? '\u{00fc}r\u{00fc}n'} tespiti',
            category: _inferCategoryFromName(name),
            stockStatus: 'Mevcut',
            sourceLineSummary: sourceLines.join('\n'),
            parserWarnings: const ['Fiyat g\u{00fc}venli okunamad\u{0131}. \u{0130}nceleme aday\u{0131}.'],
            detectionId: regionId,
            detectionIds: [regionId],
            origin: 'object_detection',
            confidence: region.confidence ?? 0.3,
            priceAmount: null,
            sourceLines: sourceLines,
            quantity: 1,
          ),
        );
      }
    }

    final remainingOcr =
        ocrLines.where((line) {
          return !usedOcrKeys.contains('${line.blockIndex}:${line.lineIndex}');
        }).toList();

    if (remainingOcr.isNotEmpty) {
      final parsedList = visualCatalogParser.parse(
        rawText: remainingOcr.map((line) => line.text).join('\n'),
        lines: remainingOcr,
      );
      for (var j = 0; j < parsedList.length; j++) {
        final parsed = parsedList[j];
        final cleanName = XRexProductTextNormalizer.normalizeProductName(
          parsed.name,
        );
        rawProducts.add(
          XRexDraftProduct(
            id:
                '${DateTime.now().microsecondsSinceEpoch}_u_${j}_${rawProducts.length}',
            name: cleanName.isEmpty ? parsed.name : cleanName,
            price: parsed.price,
            oldPrice: parsed.oldPrice,
            description: parsed.description,
            category: parsed.category,
            stockStatus: 'Mevcut',
            sourceLineSummary: parsed.sourceLines.join('\n'),
            parserWarnings: parsed.warnings,
            origin: parsed.origin,
            confidence: parsed.confidence,
            priceAmount: parsed.priceAmount,
            sourceLines: parsed.sourceLines,
            quantity: 1,
          ),
        );
      }
    }

    _enrichProductsWithPortfolio(rawProducts);

    final mergedProducts = <XRexDraftProduct>[];
    final seenNormalizedNames = <String, XRexDraftProduct>{};

    for (final prod in rawProducts) {
      final normName = _normalizeProductName(prod.name);
      if (normName.isEmpty || normName == 'isimsiz \u{00fc}r\u{00fc}n') {
        mergedProducts.add(prod);
        continue;
      }

      if (seenNormalizedNames.containsKey(normName)) {
        final existing = seenNormalizedNames[normName]!;
        existing.quantity += prod.quantity;
        if (prod.detectionId != null &&
            !existing.detectionIds.contains(prod.detectionId!)) {
          existing.detectionIds.add(prod.detectionId!);
        }
        for (final id in prod.detectionIds) {
          if (!existing.detectionIds.contains(id)) {
            existing.detectionIds.add(id);
          }
        }
        if (existing.price.isEmpty && prod.price.isNotEmpty) {
          existing.price = prod.price;
          existing.priceAmount = prod.priceAmount;
        }
      } else {
        seenNormalizedNames[normName] = prod;
        mergedProducts.add(prod);
      }
    }

    for (var k = 0; k < mergedProducts.length; k++) {
      mergedProducts[k].sourceIndex = '#${k + 1}';
    }

    return mergedProducts;
  }

  String inferCategory(String name) {
    final lower = name.toLowerCase();
    if (['koltuk', 'sandalye', 'masa', 'tabure', 'kanepe', 'puf', 'ofis', 'mobilya', 'dolap', 'komodin', 'sehpa', 'kitapl\u{0131}k', 'gard\u{0131}rop'].any(lower.contains)) return 'Mobilya';
    if (['krem', 'parf\u{00fc}m', '\u{015f}ampuan', 'ruj', 'maskara', 'kozmetik', 'sabun', 'jel', 'all\u{0131}k', 'oje', 'fond\u{00f6}ten', 'serum', 'bak\u{0131}m', 'losyon'].any(lower.contains)) return 'Kozmetik';
    if (['\u{00e7}ay', 'bitki', 'baharat', 'aktar', 'kekik', 'nane', '\u{0131}hlamur', 'papatya'].any(lower.contains)) return 'Aktar \u{00fc}r\u{00fc}nleri';
    if (['elbise', 'ti\u{015f}\u{00f6}rt', 'pantolon', '\u{00e7}orap', 'ceket', 'kaban', 'kazak', 'h\u{0131}rka', '\u{015f}ort', 'bluz', 'pijama', 'giyim'].any(lower.contains)) return 'Giyim';
    if (['g\u{00f6}zl\u{00fc}k', 'lens', '\u{00e7}er\u{00e7}eve', 'optik', 'g\u{00f6}zl\u{00fc}\u{011f}'].any(lower.contains)) return 'Gözlük';
    if (['vida', 'matkap', '\u{00e7}eki\u{00e7}', 'pense', 'tornavida', 'h\u{0131}rdavat', 'anahtar', '\u{00e7}ivi'].any(lower.contains)) return 'H\u{0131}rdavat';
    if (['defter', 'kalem', 'silgi', 'boya', 'cetvel', 'k\u{0131}rtasiye', 'kitap', 'ajanda', 'dosya'].any(lower.contains)) return 'K\u{0131}rtasiye';
    if (['bebek', 'araba', 'lego', 'oyuncak', 'barbie', 'puzzle', 'pelu\u{015f}'].any(lower.contains)) return 'Oyuncak';
    if (['elma', 'muz', 'domates', 'manav', 'sebze', 'meyve', 'limon', 'patates', 'so\u{011f}an', 'portakal', '\u{00e7}ilek'].any(lower.contains)) return 'Manav';
    if (['yast\u{0131}k', 'yorgan', 'nevresim', 'havlu', '\u{00e7}ar\u{015f}af', 'battaniye', 'tekstil'].any(lower.contains)) return 'Ev tekstili';
    if (['bardak', 'tabak', 'tencere', 'z\u{00fc}ccaciye', '\u{00e7}atal', 'ka\u{015f}\u{0131}k', 'kase', 'fincan', 'tava'].any(lower.contains)) return 'Z\u{00fc}ccaciye';
    if (['k\u{00fc}pe', 'kolye', 'y\u{00fc}z\u{00fc}k', 'saat', '\u{00e7}anta', 'aksesuar', 'bileklik', 'toka', 'kemer'].any(lower.contains)) return 'Aksesuar';
    return 'Genel';
  }

  String _inferCategoryFromName(String name) {
    return inferCategory(name);
  }

  double _horizontalOverlap(Rect a, Rect b) {
    final left = math.max(a.left, b.left);
    final right = math.min(a.right, b.right);
    return math.max(0.0, right - left);
  }

  bool _isNoiseLine(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return true;

    final noiseKeywords = [
      'kargo',
      'teslimat',
      'kupon',
      'puan',
      'yorum',
      'bedava',
      'indirim',
      'sepet',
      'stok',
      'kdv',
      'tl',
      'usd',
      'eur',
      'taksit',
      'kargo bedava',
    ];
    for (final kw in noiseKeywords) {
      if (lower.contains(kw)) return true;
    }

    if (RegExp(r'^[\d.,\s%+$\-–—•*]*$').hasMatch(lower)) return true;
    if (lower.length <= 2) return true;

    return false;
  }

  String _normalizeProductName(String name) {
    return XRexProductTextNormalizer.dedupeKey(name);
  }

  String _translateLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('termos') ||
        lower.contains('vacuum flask') ||
        lower.contains('bottle')) {
      return 'Termos';
    }
    if (lower.contains('chair') ||
        lower.contains('stool') ||
        lower.contains('tabure')) {
      return 'Plastik Tabure';
    }
    if (lower.contains('bin') ||
        lower.contains('can') ||
        lower.contains('trash')) {
      return 'Pedall\u{0131} \u{00c7}\u{00f6}p Kovas\u{0131}';
    }
    if (lower.contains('box') || lower.contains('container')) {
      return 'Plastik Saklama Kutusu';
    }
    if (lower.contains('dryer') || lower.contains('rack')) {
      return '\u{00c7}ama\u{015f}\u{0131}r Kurutmal\u{0131}\u{011f}\u{0131}';
    }
    if (lower.contains('bucket') || lower.contains('pail')) {
      return 'Plastik Kova';
    }
    if (lower.contains('cart') || lower.contains('trolley')) {
      return 'Market Arabas\u{0131}';
    }

    return label[0].toUpperCase() + label.substring(1);
  }

  void _enrichProductsWithPortfolio(List<XRexDraftProduct> rawProducts) {
    final portfolioService = XRexPortfolioService();
    for (var i = 0; i < rawProducts.length; i++) {
      final prod = rawProducts[i];
      if (prod.name.isEmpty) continue;

      prod.rawOcrText = prod.name;
      prod.isApproved = false;

      final matches = portfolioService.findTopMatches(prod.name, limit: 3);
      if (matches.isNotEmpty) {
        final bestMatch = matches.first;
        final bestProd = bestMatch.product;
        final confidence = bestMatch.confidence;

        prod.confidence = confidence;
        prod.suggestions = matches.map((m) => m.product).toList();

        if (confidence >= 0.85) {
          prod.name = bestProd.name;
          prod.category = bestProd.category;
          prod.description = bestProd.description;

          if (prod.price.isEmpty && bestProd.price.isNotEmpty) {
            prod.price = bestProd.price;
            final parsedAmount = XRexPriceParser.parseAmount(bestProd.price);
            if (parsedAmount != null) {
              prod.priceAmount = parsedAmount.toDouble();
            }
          }

          final matchPercentage = (confidence * 100).toStringAsFixed(0);
          prod.parserWarnings = [
            ...prod.parserWarnings,
            'G\u{00fc}\u{00e7}l\u{00fc} e\u{015f}le\u{015f}me: ${bestProd.name} (%$matchPercentage)',
          ];
          prod.origin = 'portfolio_matched_strong';
        } else if (confidence >= 0.60) {
          prod.name = 'E\u{015f}le\u{015f}me kontrol\u{00fc} gerekli';
          prod.category = bestProd.category;
          prod.description = 'E\u{015f}le\u{015f}me kontrol\u{00fc} gerekli. En yak\u{0131}n e\u{015f}le\u{015f}en portf\u{00f6}y \u{00fc}r\u{00fc}n\u{00fc}n\u{00fc} listeden se\u{00e7}ebilirsiniz.';

          final matchPercentage = (confidence * 100).toStringAsFixed(0);
          prod.parserWarnings = [
            ...prod.parserWarnings,
            'Zay\u{0131}f e\u{015f}le\u{015f}me: En yak\u{0131}n aday ${bestProd.name} (%$matchPercentage)',
          ];
          prod.origin = 'portfolio_matched_weak';
        } else {
          prod.name = 'Bilinmeyen \u{00fc}r\u{00fc}n';
          prod.category = 'Genel';
          prod.description = 'Bu \u{00fc}r\u{00fc}n portf\u{00f6}yde bulunamad\u{0131} veya e\u{015f}le\u{015f}me skoru \u{00e7}ok d\u{00fc}\u{015f}\u{00fc}k. L\u{00fc}tfen elle d\u{00fc}zenleyin.';
          prod.suggestions = const [];
          prod.parserWarnings = [
            ...prod.parserWarnings,
            'E\u{015f}le\u{015f}me bulunamad\u{0131} (Skor %${(confidence * 100).toStringAsFixed(0)} < %60)',
          ];
          prod.origin = 'unmatched';
        }
      } else {
        prod.name = 'Bilinmeyen \u{00fc}r\u{00fc}n';
        prod.category = 'Genel';
        prod.description = 'Bu \u{00fc}r\u{00fc}n portf\u{00f6}yde bulunamad\u{0131}. L\u{00fc}tfen elle d\u{00fc}zenleyin.';
        prod.confidence = 0.0;
        prod.suggestions = const [];
        prod.parserWarnings = [
          ...prod.parserWarnings,
          'E\u{015f}le\u{015f}me bulunamad\u{0131}',
        ];
        prod.origin = 'unmatched';
      }
    }
  }
}