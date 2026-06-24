import 'dart:ui';
import 'dart:math' as math;

import '../models/xrex_detected_region.dart';
import '../models/xrex_ocr_line.dart';
import '../models/xrex_parsed_product.dart';
import 'xrex_price_parser.dart';
import 'xrex_text_parser_service.dart';

class XRexVisualCatalogParser {
  final XRexTextParserService fallbackTextParserService;

  const XRexVisualCatalogParser({
    this.fallbackTextParserService = const XRexTextParserService(),
  });

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
    final products = <XRexParsedProduct>[];
    final seenPriceKeys = <String>{};
    final usedContentKeys = <String>{};

    // 1. Extract all potential prices first
    final priceLines = lines.where((line) => _extractPrice(line.text) != null).toList();
    // Sort prices: Top-to-bottom, then left-to-right
    priceLines.sort((a, b) {
      if ((a.centerY - b.centerY).abs() > 30) return a.centerY.compareTo(b.centerY);
      return a.centerX.compareTo(b.centerX);
    });

    for (final priceLine in priceLines) {
      if (seenPriceKeys.contains(priceLine.key)) continue;

      final price = _extractPrice(priceLine.text);
      if (price == null) continue;
      final priceAmount = _parseNumericPrice(price);

      // 2. Find product name candidates ABOVE this price tag
      // In supermarket shelves, price is almost always BELOW the product.
      final candidatesAbove = lines.where((l) {
        if (l.key == priceLine.key || usedContentKeys.contains(l.key)) return false;
        if (_extractPrice(l.text) != null) return false;
        if (_isNoiseLine(l.text)) return false;

        // Must be above and within a horizontal "corridor"
        final isAbove = l.centerY < priceLine.centerY && (priceLine.centerY - l.centerY) < 450;
        final hDist = (l.centerX - priceLine.centerX).abs();
        final corridorWidth = math.max(l.boundingBox.width, priceLine.boundingBox.width) * 0.8 + 50;

        return isAbove && hDist < corridorWidth;
      }).toList();

      // Sort by proximity to the price (bottom-up)
      candidatesAbove.sort((a, b) => b.centerY.compareTo(a.centerY));

      // 3. Look for Brand (often slightly further away or repeated)
      final brandLine = lines.where((l) {
        final isBrand = _isBrandName(l.text);
        if (!isBrand) return false;
        final isNear = (l.centerX - priceLine.centerX).abs() < 200 && (priceLine.centerY - l.centerY) < 600;
        return isNear;
      }).toList();

      String brandPrefix = "";
      if (brandLine.isNotEmpty) {
        brandLine.sort((a, b) => (a.centerY - priceLine.centerY).abs().compareTo((b.centerY - priceLine.centerY).abs()));
        brandPrefix = brandLine.first.text;
      }

      // Construct name from lines closest to price
      final selectedLines = candidatesAbove.take(3).toList().reversed.toList();
      String name = _buildName("", selectedLines);

      if (brandPrefix.isNotEmpty && !name.toLowerCase().contains(brandPrefix.toLowerCase())) {
        name = "$brandPrefix $name";
      }

      if (name == "İsimsiz ürün" || name.isEmpty) {
        // Fallback: use text on the same line as price if name is still empty
        final sameLine = lines.where((l) => l.key != priceLine.key && (l.centerY - priceLine.centerY).abs() < 20).toList();
        if (sameLine.isNotEmpty) {
          name = _buildName(name, sameLine);
        }
      }

      for (final l in selectedLines) {
        usedContentKeys.add(l.key);
      }
      seenPriceKeys.add(priceLine.key);

      final hasValidName = name.trim().isNotEmpty && name != 'İsimsiz ürün';
      final category = _inferCategory("$name ${priceLine.text}");

      products.add(
        XRexParsedProduct(
          name: name,
          price: price,
          oldPrice: '',
          description: "Raf konumu tespiti",
          category: category,
          sourceRect: _unionRects([...selectedLines.map((e) => e.boundingBox), priceLine.boundingBox]),
          confidence: hasValidName ? 0.90 : 0.40,
          sourceLines: [...selectedLines.map((e) => e.text), priceLine.text],
          warnings: hasValidName ? [] : ["Ürün adı belirsiz."],
          origin: 'visual_shelf_parser',
          priceAmount: priceAmount?.toDouble(),
        ),
      );
    }

    return products;
  }

  bool _isBrandName(String text) {
    final lower = text.toLowerCase().trim();
    const brands = [
      'ülker', 'eti', 'dankek', 'biscolata', 'torku', 'şölen', 'nestle', 'tadelle',
      'biskrem', 'hanımeller', 'halley', 'ikram', 'probis', 'çokoprens', 'çizi',
      'bebe', 'cicibebe', 'luppo', 'milka', 'şerefe', 'uno', 'laviva'
    ];
    return brands.any((brand) => lower.contains(brand));
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
    var primary = sameLineName.trim();
    if (primary.isNotEmpty && primary.length > 3) return primary;

    final joined =
        nameLines
            .map((line) => _cleanProductName(line.text))
            .where((line) => line.isNotEmpty && line.length > 1)
            .join(' ')
            .trim();

    if (primary.isNotEmpty && joined.isEmpty) return primary;
    if (primary.isEmpty && joined.isEmpty) return 'İsimsiz ürün';

    return primary.isNotEmpty ? '$primary $joined'.trim() : joined;
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
    return XRexPriceParser.extractPrice(text);
  }

  num? _parseNumericPrice(String value) {
    return XRexPriceParser.parseAmount(value);
  }

  String _cleanProductName(String value) {
    var cleaned = value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[^\wğüşıöçĞÜŞİÖÇ]+'), '')
        .replaceAll(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+$'), '')
        .trim();

    // Reject short junk like "IAUM", "X1", ".."
    if (cleaned.length < 3 && !RegExp(r'\d').hasMatch(cleaned)) return '';

    // Remove nonsense OCR fragments (usually all caps with no vowels and mixed symbols)
    // Or strings with high consonant-to-length ratio that aren't common abbreviations
    final vowels = RegExp(r'[aeiouöüıiAEIOUÖÜİI]');
    if (cleaned.length > 3 && !cleaned.contains(vowels)) {
       // If it's not a known brand/short word, it's likely junk
       if (!_isBrandName(cleaned)) return '';
    }

    return cleaned;
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

    // Reject lines that are just numbers (unless they look like price)
    if (RegExp(r'^\d+$').hasMatch(normalized)) return true;

    // Reject lines with too many non-alphanumeric chars
    final nonAlphaNumCount = normalized.replaceAll(RegExp(r'[a-zA-Z0-9ğüşıöçĞÜŞİÖÇ]'), '').length;
    if (nonAlphaNumCount > normalized.length * 0.4) return true;

    // Pure symbol checks
    if (normalized == '\$' || normalized == '₺' || normalized == 'tl') return true;

    if (RegExp(r'^\W+$').hasMatch(normalized)) return true;
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(normalized)) return true;
    if (normalized.contains('★') || normalized.contains('⭐')) return true;

    const noiseTerms = [
      'arama', 'ara', 'sepet', 'favori', 'takip', 'kargo', 'teslimat', 'kupon', 'taksit',
      'puan', 'yorum', 'ana sayfa', 'tüm ürünler', 'fırsat', 'satıcı', 'mağazada ara',
      'video', 'en çok ziyaret', 'avantajlı ürün', 'menü', 'koleksiyon', 'tıkla',
      'kampanya', 'paylaş', 'beğen', 'detay', 'indirim', 'seçenek', 'kdv', 'dahil',
      'stokta', 'tükendi', 'hızlı gönderim', 'aynı gün', 'kargo bedava', 'adet', 'paket',
      'yeni', 'popüler', 'stok', 'fiyat',
      // English noise words
      'shipping', 'delivery', 'coupon', 'rating', 'review', 'search', 'menu', 'cart',
      'free', 'discount', 'details', 'item', 'stars', 'buy', 'now', 'add',
    ];

    return noiseTerms.any((term) => normalized == term || normalized.contains(' $term') || normalized.contains('$term '));
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
