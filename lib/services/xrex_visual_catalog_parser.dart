import 'dart:ui';
import 'dart:math' as math;

import '../models/xrex_detected_region.dart';
import '../models/xrex_ocr_line.dart';
import '../models/xrex_parsed_product.dart';
import 'xrex_text_parser_service.dart';

class XRexVisualCatalogParser {
  final XRexTextParserService fallbackTextParserService;

  const XRexVisualCatalogParser({
    this.fallbackTextParserService = const XRexTextParserService(),
  });

  static final RegExp _pricePattern = RegExp(
    r'(?:sepette\s*)?(?:₺|TL|TRY)?\s*(?:\d{1,3}(?:[.\s]\d{3})+(?:,\d{1,2})?|\d{1,6}(?:[.,]\d{1,2})?)\s*(?:₺|TL|TRY|tl|try)?',
    caseSensitive: false,
  );

  List<XRexParsedProduct> parse({
    required String rawText,
    required List<XRexOcrLine> lines,
    List<XRexDetectedRegion> regions = const [],
  }) {
    final candidates =
        lines
            .map(_LineCandidate.fromOcrLine)
            .where((line) =>
                line.text.trim().isNotEmpty &&
                (!_isNoiseLine(line.text) || _extractPrice(line.text) != null))
            .toList()
          ..sort(_compareByPosition);

    final visualProducts = _parseByCoordinates(candidates);
    if (visualProducts.isNotEmpty) return visualProducts;

    return fallbackTextParserService
        .parseProducts(rawText)
        .map(
          (product) => product.copyWith(
            category: _inferCategory(product.name),
            confidence: _scoreProduct(product.name, product.price, 'Genel', []),
            origin: 'text_parser',
            priceAmount: _parseNumericPrice(product.price)?.toDouble(),
          ),
        )
        .toList();
  }

  List<XRexParsedProduct> _parseByCoordinates(List<_LineCandidate> lines) {
    // 1. Group lines into columns based on horizontal proximity.
    final columns = <List<_LineCandidate>>[];
    for (final line in lines) {
      bool placed = false;
      for (final col in columns) {
        if (_isSameProductColumn(line, col.first)) {
          col.add(line);
          placed = true;
          break;
        }
      }
      if (!placed) {
        columns.add([line]);
      }
    }

    final products = <XRexParsedProduct>[];
    final seenProducts = <String>{};

    for (final col in columns) {
      // Sort lines in column by Y ascending (top to bottom)
      col.sort((a, b) => a.centerY.compareTo(b.centerY));

      final priceLines =
          col.where((line) => _extractPrice(line.text) != null).toList();
      final contentLines =
          col.where((line) => _extractPrice(line.text) == null).toList();

      final usedPriceKeys = <String>{};
      final usedContentKeys = <String>{};

      for (final priceLine in priceLines) {
        if (usedPriceKeys.contains(priceLine.key)) continue;
        if (_isLikelyOldPrice(priceLine, priceLines)) continue;

        final price = _extractPrice(priceLine.text);
        if (price == null) continue;
        final priceAmount = _parseNumericPrice(price);

        final oldPriceLine = _nearestOldPriceLine(priceLine, priceLines);
        final oldPrice = oldPriceLine != null ? _extractPrice(oldPriceLine.text) : null;

        final nameLines = contentLines
            .where(
              (line) =>
                  !usedContentKeys.contains(line.key) &&
                  line.centerY < priceLine.centerY &&
                  priceLine.centerY - line.centerY <= 300 &&
                  !_isNoiseLine(line.text),
            )
            .toList()
          ..sort((a, b) => b.centerY.compareTo(a.centerY));

        final selectedNameLines = nameLines.take(3).toList().reversed.toList();
        final sameLineName = _cleanProductName(
          priceLine.text.replaceFirst(_pricePattern, ''),
        );
        final name = _buildName(sameLineName, selectedNameLines);

        for (final nl in selectedNameLines) {
          usedContentKeys.add(nl.key);
        }

        final sourceTexts = <String>[
          ...selectedNameLines.map((line) => line.text),
          priceLine.text,
          if (oldPriceLine != null) oldPriceLine.text,
        ];
        final category = _inferCategory('$name ${sourceTexts.join(' ')}');
        final key = '${_normalizeKey(name)}|${_normalizeKey(price)}';
        if (!seenProducts.add(key)) continue;

        usedPriceKeys.add(priceLine.key);
        if (oldPriceLine != null) usedPriceKeys.add(oldPriceLine.key);

        final hasValidName = name.trim().isNotEmpty && name != 'İsimsiz ürün' && !_isNoiseLine(name);
        final hasValidPrice = price.trim().isNotEmpty;
        final isReady = hasValidName && hasValidPrice;

        final warnings = <String>[];
        if (!isReady) {
          if (!hasValidName) warnings.add('Ürün adı güvenli okunamadı.');
          if (!hasValidPrice) warnings.add('Fiyat güvenli okunamadı.');
        }
        if (category == 'Genel') {
          warnings.add('Kategori kullanıcı kontrolü istiyor.');
        }

        products.add(
          XRexParsedProduct(
            name: name,
            price: price,
            oldPrice: oldPrice ?? '',
            description: _buildDescription(selectedNameLines, priceLine, col),
            category: category,
            sourceRect: _unionRects([
              ...selectedNameLines.map((line) => line.boundingBox),
              priceLine.boundingBox,
              if (oldPriceLine != null) oldPriceLine.boundingBox,
            ]),
            confidence: isReady ? 0.85 : 0.30,
            sourceLines: sourceTexts,
            warnings: warnings,
            origin: 'visual_ocr',
            priceAmount: priceAmount?.toDouble(),
          ),
        );
      }

      // Add unpaired non-noise lines as candidates
      for (final line in contentLines) {
        if (usedContentKeys.contains(line.key)) continue;
        if (_isNoiseLine(line.text)) continue;

        final name = _cleanProductName(line.text);
        if (name.isEmpty) continue;

        final key = '${_normalizeKey(name)}|empty_price';
        if (!seenProducts.add(key)) continue;

        usedContentKeys.add(line.key);

        products.add(
          XRexParsedProduct(
            name: name,
            price: '',
            oldPrice: '',
            description: '',
            category: _inferCategory(name),
            sourceRect: line.boundingBox,
            confidence: 0.30,
            sourceLines: [line.text],
            warnings: const ['Fiyat güvenli okunamadı. İnceleme adayı.'],
            origin: 'visual_ocr',
            priceAmount: null,
          ),
        );
      }
    }

    // Sort products by visual position (row-by-row, left-to-right)
    products.sort((a, b) {
      if (a.sourceRect == null || b.sourceRect == null) return 0;
      final aCenterY = a.sourceRect!.top + a.sourceRect!.height / 2;
      final bCenterY = b.sourceRect!.top + b.sourceRect!.height / 2;
      final yDiff = (aCenterY - bCenterY).abs();
      if (yDiff > 100) {
        return aCenterY.compareTo(bCenterY);
      }
      final aCenterX = a.sourceRect!.left + a.sourceRect!.width / 2;
      final bCenterX = b.sourceRect!.left + b.sourceRect!.width / 2;
      return aCenterX.compareTo(bCenterX);
    });

    return products;
  }

  _LineCandidate? _nearestOldPriceLine(
    _LineCandidate priceLine,
    List<_LineCandidate> priceLines,
  ) {
    final text = priceLine.normalizedText;
    final canPair =
        text.contains('sepette') ||
        text.contains('indirim') ||
        text.contains('kupon');
    if (!canPair) return null;

    final nearby =
        priceLines
            .where(
              (line) =>
                  line.key != priceLine.key &&
                  line.centerY > priceLine.centerY &&
                  line.centerY - priceLine.centerY <= 120 &&
                  _isSameProductColumn(line, priceLine),
            )
            .toList()
          ..sort(
            (a, b) => (a.centerY - priceLine.centerY).compareTo(
              b.centerY - priceLine.centerY,
            ),
          );

    return nearby.isEmpty ? null : nearby.first;
  }

  bool _isLikelyOldPrice(
    _LineCandidate priceLine,
    List<_LineCandidate> priceLines,
  ) {
    if (priceLine.normalizedText.contains('sepette')) return false;

    return priceLines.any(
      (line) =>
          line.key != priceLine.key &&
          line.centerY < priceLine.centerY &&
          priceLine.centerY - line.centerY <= 120 &&
          line.normalizedText.contains('sepette') &&
          _isSameProductColumn(line, priceLine),
    );
  }

  String _buildName(String sameLineName, List<_LineCandidate> nameLines) {
    if (sameLineName.trim().isNotEmpty) return sameLineName.trim();

    final joined =
        nameLines
            .map((line) => _cleanProductName(line.text))
            .where((line) => line.isNotEmpty)
            .join(' ')
            .trim();

    return joined.isEmpty ? 'İsimsiz ürün' : joined;
  }

  String _buildDescription(
    List<_LineCandidate> nameLines,
    _LineCandidate priceLine,
    List<_LineCandidate> lines,
  ) {
    final nameBottom =
        nameLines.isEmpty
            ? priceLine.boundingBox.top
            : nameLines.map((line) => line.boundingBox.bottom).reduce(math.max);

    final descriptionLines =
        lines
            .where(
              (line) =>
                  line.centerY > nameBottom &&
                  line.centerY < priceLine.centerY &&
                  !_isNoiseLine(line.text) &&
                  _extractPrice(line.text) == null &&
                  _isSameProductColumn(line, priceLine),
            )
            .map((line) => _cleanProductName(line.text))
            .where((line) => line.isNotEmpty)
            .take(1)
            .toList();

    return descriptionLines.join(' ');
  }

  String? _extractPrice(String text) {
    final match = _pricePattern.firstMatch(text);
    final value = match?.group(0)?.trim();
    if (value == null || value.isEmpty) return null;
    return _looksLikePrice(value, text) ? value : null;
  }

  bool _looksLikePrice(String value, String fullLine) {
    final normalizedLine = fullLine.toLowerCase();
    if (RegExp(r'\d{1,2}:\d{2}').hasMatch(normalizedLine)) return false;
    if (normalizedLine.contains('+') && !normalizedLine.contains('tl')) {
      return false;
    }
    if (normalizedLine.contains('puan') || normalizedLine.contains('yorum')) {
      return false;
    }

    final hasCurrency =
        normalizedLine.contains('tl') ||
        normalizedLine.contains('try') ||
        normalizedLine.contains('₺') ||
        normalizedLine.contains('\$');
    if (hasCurrency) return true;

    final numeric = _parseNumericPrice(value);
    return numeric != null && numeric >= 10;
  }

  num? _parseNumericPrice(String value) {
    var normalized =
        value
            .replaceAll(RegExp(r'[^0-9,.\s]'), '')
            .replaceAll(RegExp(r'\s+'), '')
            .trim();
    if (normalized.isEmpty) return null;

    final hasComma = normalized.contains(',');
    final hasDot = normalized.contains('.');
    if (hasComma && hasDot) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (hasComma) {
      normalized = normalized.replaceAll(',', '.');
    } else if (hasDot) {
      final parts = normalized.split('.');
      if (parts.length > 1 && parts.last.length == 3) {
        normalized = normalized.replaceAll('.', '');
      }
    }

    return num.tryParse(normalized);
  }

  String _cleanProductName(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[^\wğüşıöçĞÜŞİÖÇ]+'), '')
        .replaceAll(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+$'), '')
        .trim();
  }

  String _inferCategory(String value) {
    final normalized = value.toLowerCase();
    if (_containsAny(normalized, [
      'koltuk',
      'sandalye',
      'masa',
      'tabure',
      'kanepe',
      'puf',
      'ofis',
      'mobilya',
      'dolap',
      'komodin',
      'sehpa',
      'kitaplık',
      'gardırop',
    ])) {
      return 'Mobilya';
    }
    if (_containsAny(normalized, [
      'çorap',
      'pijama',
      'elbise',
      'gömlek',
      'pantolon',
      'ayakkabı',
      'mont',
      'takım',
      'ceket',
      'kaban',
      'kazak',
      'hırka',
      'tişört',
      'yelek',
      'etek',
      'bluz',
      'şort',
      'tayt',
      'iç giyim',
    ])) {
      return 'Giyim';
    }
    if (_containsAny(normalized, ['gözlük', 'gözlüğ', 'lens', 'çerçeve', 'optik'])) {
      return 'Gözlük';
    }
    if (_containsAny(normalized, [
      'krem',
      'parfüm',
      'şampuan',
      'kozmetik',
      'ruj',
      'oje',
      'maskara',
      'far',
      'fondöten',
      'allık',
      'serum',
      'losyon',
      'makyaj',
      'sabun',
      'duş jeli',
    ])) {
      return 'Kozmetik';
    }
    if (_containsAny(normalized, [
      'matkap',
      'vida',
      'anahtar',
      'hırdavat',
      'pense',
      'çekiç',
      'tornavida',
      'testere',
      'alet çantası',
      'somun',
      'cıvata',
    ])) {
      return 'Hırdavat';
    }
    if (_containsAny(normalized, [
      'defter',
      'kalem',
      'kitap',
      'kırtasiye',
      'silgi',
      'cetvel',
      'boya',
      'makas',
      'zımba',
      'dosya',
      'klasör',
    ])) {
      return 'Kırtasiye';
    }
    if (_containsAny(normalized, [
      'çay',
      'baharat',
      'yağ',
      'aktar',
      'kekik',
      'nane',
      'zencefil',
      'zerdeçal',
      'ıhlamur',
      'adaçayı',
      'kimyon',
      'karabiber',
    ])) {
      return 'Aktar';
    }
    return 'Genel';
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }

  bool _isSameProductColumn(_LineCandidate a, _LineCandidate b) {
    final overlap = _horizontalOverlap(a.boundingBox, b.boundingBox);
    final centerDistance = (a.centerX - b.centerX).abs();
    final tolerance =
        math.max(a.boundingBox.width, b.boundingBox.width) * 0.4 + 40;
    return overlap > 0 || centerDistance <= tolerance;
  }

  double _horizontalOverlap(Rect a, Rect b) {
    final left = math.max(a.left, b.left);
    final right = math.min(a.right, b.right);
    return math.max(0, right - left);
  }

  Rect _unionRects(List<Rect> rects) {
    if (rects.isEmpty) return Rect.zero;

    var left = rects.first.left;
    var top = rects.first.top;
    var right = rects.first.right;
    var bottom = rects.first.bottom;

    for (final rect in rects.skip(1)) {
      left = math.min(left, rect.left);
      top = math.min(top, rect.top);
      right = math.max(right, rect.right);
      bottom = math.max(bottom, rect.bottom);
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  double _scoreProduct(
    String name,
    String price,
    String category,
    List<String> warnings,
  ) {
    var score = 0.35;
    if (name.trim().isNotEmpty && name != 'İsimsiz ürün') score += 0.3;
    if (price.trim().isNotEmpty) score += 0.25;
    if (category != 'Genel') score += 0.1;
    if (warnings.isEmpty) score += 0.05;
    return math.min(score, 0.95);
  }

  bool _isNoiseLine(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (normalized.length < 2) return true;

    // Single digits/numbers check
    if (RegExp(r'^\d+$').hasMatch(normalized)) return true;

    // Pure symbol checks
    if (normalized == '\$' || normalized == '₺' || normalized == 'tl') return true;

    if (RegExp(r'^\W+$').hasMatch(normalized)) return true;
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(normalized)) return true;
    if (normalized.contains('★') || normalized.contains('⭐')) return true;
    if (RegExp(r'^\d+[.,]\d+\s*\(').hasMatch(normalized)) return true;

    const noiseTerms = [
      'arama',
      'ara',
      'sepet',
      'favori',
      'takip',
      'kargo',
      'teslimat',
      'kupon',
      'taksit',
      'puan',
      'yorum',
      'ana sayfa',
      'tüm ürünler',
      'fırsat',
      'satıcı',
      'mağazada ara',
      'video',
      'en çok ziyaret',
      'avantajlı ürün',
      'menü',
      'koleksiyon',
      'tıkla',
      'kampanya',
      'paylaş',
      'beğen',
      'detay',
      'indirim',
      'seçenek',
      // English noise words
      'shipping',
      'delivery',
      'coupon',
      'rating',
      'review',
      'search',
      'menu',
      'cart',
      'free',
      'discount',
      'details',
      'item',
      'stars',
    ];

    return noiseTerms.any(normalized.contains);
  }

  String _normalizeKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  int _compareByPosition(_LineCandidate a, _LineCandidate b) {
    final yCompare = a.centerY.compareTo(b.centerY);
    if (yCompare != 0) return yCompare;
    return a.centerX.compareTo(b.centerX);
  }
}

class _LineCandidate {
  final String text;
  final String normalizedText;
  final Rect boundingBox;
  final int blockIndex;
  final int lineIndex;

  const _LineCandidate({
    required this.text,
    required this.normalizedText,
    required this.boundingBox,
    required this.blockIndex,
    required this.lineIndex,
  });

  factory _LineCandidate.fromOcrLine(XRexOcrLine line) {
    return _LineCandidate(
      text: line.text.trim(),
      normalizedText: line.text.trim().toLowerCase(),
      boundingBox: line.boundingBox,
      blockIndex: line.blockIndex,
      lineIndex: line.lineIndex,
    );
  }

  String get key =>
      '$blockIndex:$lineIndex:${boundingBox.left}:${boundingBox.top}';

  double get centerX => boundingBox.left + (boundingBox.width / 2);

  double get centerY => boundingBox.top + (boundingBox.height / 2);
}
