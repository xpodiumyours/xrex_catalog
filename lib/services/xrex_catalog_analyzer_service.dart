import 'dart:math' as math;
import 'dart:ui';
import '../models/xrex_detected_region.dart';
import '../models/xrex_draft_product.dart';
import '../models/xrex_ocr_line.dart';
import 'xrex_object_detection_service.dart';
import 'xrex_ocr_service.dart';
import 'xrex_visual_catalog_parser.dart';

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
  final XRexObjectDetectionService objectDetectionService;
  final XRexOcrService ocrService;
  final XRexVisualCatalogParser visualCatalogParser;

  const XRexCatalogAnalyzerService({
    this.objectDetectionService = const XRexObjectDetectionService(),
    this.ocrService = const XRexOcrService(),
    this.visualCatalogParser = const XRexVisualCatalogParser(),
  });

  Future<XRexCatalogAnalysisResult> analyzeImagePath(String imagePath) async {
    final regions = await objectDetectionService.detectObjectsFromImagePath(
      imagePath,
    );
    final ocrResult = await ocrService.readResultFromImagePath(imagePath);
    final products = _mergeRegionsAndText(regions, ocrResult.lines);

    return XRexCatalogAnalysisResult(
      rawText: ocrResult.rawText,
      regions: regions,
      products: products,
    );
  }

  List<XRexDraftProduct> _mergeRegionsAndText(
    List<XRexDetectedRegion> regions,
    List<XRexOcrLine> ocrLines,
  ) {
    final rawProducts = <XRexDraftProduct>[];
    final usedOcrKeys = <String>{};

    // 1. Map OCR lines to detected visual regions based on horizontal/vertical coordinates
    for (var i = 0; i < regions.length; i++) {
      final region = regions[i];
      final regionId = region.id;

      final matchedOcr = ocrLines.where((line) {
        final lineBox = line.boundingBox;
        final overlap = _horizontalOverlap(region.boundingBox, lineBox);
        if (overlap <= 0) return false;

        // Prevent cross-column matching by verifying center proximity or a significant overlap fraction
        final lineCenter = (lineBox.left + lineBox.right) / 2;
        final isHorizontallyAligned = lineCenter >= region.boundingBox.left - 20 &&
            lineCenter <= region.boundingBox.right + 20;

        if (!isHorizontallyAligned && overlap < math.min(lineBox.width, region.boundingBox.width) * 0.3) {
          return false;
        }

        // Check if the text resides inside the box or immediately below
        final isInside = lineBox.top >= region.boundingBox.top - 20 &&
            lineBox.bottom <= region.boundingBox.bottom + 20;
        final isBelow = lineBox.top >= region.boundingBox.bottom - 20 &&
            lineBox.top - region.boundingBox.bottom <= 120;
        return isInside || isBelow;
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
          rawProducts.add(
            XRexDraftProduct(
              id: '${DateTime.now().microsecondsSinceEpoch}_r_${i}_${rawProducts.length}',
              name: parsed.name,
              price: parsed.price,
              oldPrice: parsed.oldPrice,
              description: parsed.description.isNotEmpty
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
        // No visual name/price parsed from coordinates. Infer name from lines or label
        final nonNoiseText = matchedOcr
            .where((line) => line.text.trim().isNotEmpty && !_isNoiseLine(line.text))
            .map((line) => line.text.trim())
            .join(' ');

        String name = '';
        if (nonNoiseText.isNotEmpty) {
          name = nonNoiseText;
        } else if (region.label != null && region.label!.isNotEmpty) {
          name = _translateLabel(region.label!);
        } else {
          name = 'Görsel Ürün #${i + 1}';
        }

        final sourceLines = matchedOcr.map((line) => line.text).toList();
        rawProducts.add(
          XRexDraftProduct(
            id: '${DateTime.now().microsecondsSinceEpoch}_r_${i}_${rawProducts.length}',
            name: name,
            price: '',
            oldPrice: '',
            description: 'Fotoğraftan ${region.label ?? 'ürün'} tespiti',
            category: _inferCategoryFromName(name),
            stockStatus: 'Mevcut',
            sourceLineSummary: sourceLines.join('\n'),
            parserWarnings: const ['Fiyat güvenli okunamadı. İnceleme adayı.'],
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

    // 2. Process remaining unpaired OCR lines
    final remainingOcr = ocrLines.where((line) {
      return !usedOcrKeys.contains('${line.blockIndex}:${line.lineIndex}');
    }).toList();

    if (remainingOcr.isNotEmpty) {
      final parsedList = visualCatalogParser.parse(
        rawText: '',
        lines: remainingOcr,
      );
      for (var j = 0; j < parsedList.length; j++) {
        final parsed = parsedList[j];
        rawProducts.add(
          XRexDraftProduct(
            id: '${DateTime.now().microsecondsSinceEpoch}_u_${j}_${rawProducts.length}',
            name: parsed.name,
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

    // 3. Deduplicate and merge products (Benzerleri Birleştir)
    final mergedProducts = <XRexDraftProduct>[];
    final seenNormalizedNames = <String, XRexDraftProduct>{};

    for (final prod in rawProducts) {
      final normName = _normalizeProductName(prod.name);
      if (normName.isEmpty || normName == 'isimsiz ürün') {
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

    // Assign sequence numbers sourceIndex (#1, #2, etc.) to final items
    for (var k = 0; k < mergedProducts.length; k++) {
      mergedProducts[k].sourceIndex = '#${k + 1}';
    }

    return mergedProducts;
  }

  String _inferCategoryFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('çay') || lower.contains('bitki') || lower.contains('baharat')) return 'Aktar ürünleri';
    if (lower.contains('elbise') || lower.contains('tişört') || lower.contains('pantolon')) return 'Giyim';
    if (lower.contains('gözlük')) return 'Gözlük';
    if (lower.contains('vida') || lower.contains('matkap')) return 'Hırdavat';
    return 'Genel';
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
      'kargo', 'teslimat', 'kupon', 'puan', 'yorum', 'bedava', 'indirim',
      'sepet', 'stok', 'kdv', 'tl', 'usd', 'eur', 'taksit', 'kargo bedava'
    ];
    for (final kw in noiseKeywords) {
      if (lower.contains(kw)) return true;
    }

    if (RegExp(r'^[\d.,\s%+$\-–—•*]*$').hasMatch(lower)) return true;
    if (lower.length <= 2) return true;

    return false;
  }

  String _normalizeProductName(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[.,\-–—_+*]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
      return 'Pedallı Çöp Kovası';
    }
    if (lower.contains('box') || lower.contains('container')) {
      return 'Plastik Saklama Kutusu';
    }
    if (lower.contains('dryer') || lower.contains('rack')) {
      return 'Çamaşır Kurutmalığı';
    }
    if (lower.contains('bucket') || lower.contains('pail')) {
      return 'Plastik Kova';
    }
    if (lower.contains('cart') || lower.contains('trolley')) {
      return 'Market Arabası';
    }

    return label[0].toUpperCase() + label.substring(1);
  }
}
