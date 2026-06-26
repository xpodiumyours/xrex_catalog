// ignore_for_file: deprecated_member_use

import 'dart:ui';
import 'dart:math' as math;

import '../models/xrex_detected_region.dart';
import '../models/xrex_ocr_line.dart';
import '../models/xrex_parsed_product.dart';
import 'xrex_price_parser.dart';
import 'xrex_product_text_normalizer.dart';
import 'xrex_text_parser_service.dart';

class XRexVisualCatalogParser {
  final XRexTextParserService fallbackTextParserService;

  static final RegExp _onlyDigitsPattern = RegExp(r'^\d+$');
  static final RegExp _turkishAlphaNumericPattern = RegExp('[a-zA-Z0-9\u{011f}\u{00fc}\u{015f}\u{0131}\u{00f6}\u{00e7}\u{011e}\u{00dc}\u{015e}\u{0130}\u{00d6}\u{00c7}]');
  static final RegExp _onlySymbolsPattern = RegExp(r'^\W+$');
  static final RegExp _timePattern = RegExp(r'^\d{1,2}:\d{2}$');

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
            .where(
              (line) =>
                  line.text.trim().isNotEmpty &&
                  (!_isNoiseLine(line.text) ||
                      _extractPrice(line.text) != null),
            )
            .toList()
          ..sort(_compareByPosition);

    // 1. Try parsing by coordinates (needs prices)
    final visualProducts = _parseByCoordinates(candidates);
    if (visualProducts.isNotEmpty) return visualProducts;

    // 2. Try fallback text parser (needs prices)
    final textProducts = fallbackTextParserService
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
    if (textProducts.isNotEmpty) return textProducts;

    // 3. Fallback: Parse priceless products by grouping non-noise close lines
    return _parseWithoutPrices(candidates);
  }

  double _horizontalOverlap(Rect a, Rect b) {
    final left = math.max(a.left, b.left);
    final right = math.min(a.right, b.right);
    return math.max(0.0, right - left);
  }

  List<XRexParsedProduct> _parseWithoutPrices(List<_LineCandidate> lines) {
    final products = <XRexParsedProduct>[];
    final nonNoise = lines.where((l) => !_isNoiseLine(l.text)).toList();

    nonNoise.sort((a, b) => a.centerY.compareTo(b.centerY));

    final groups = <List<_LineCandidate>>[];
    for (final line in nonNoise) {
      bool added = false;
      for (final group in groups) {
        final last = group.last;
        final vDist = (line.centerY - last.centerY).abs();
        final hOverlap = _horizontalOverlap(line.boundingBox, last.boundingBox);
        final hDist = (line.centerX - last.centerX).abs();

        if (vDist < 60 && (hOverlap > 0 || hDist < 150)) {
          group.add(line);
          added = true;
          break;
        }
      }
      if (!added) {
        groups.add([line]);
      }
    }

    for (final group in groups) {
      final name = _buildName("", group);
      if (name.isEmpty || name == '\u{0130}simsiz \u{00fc}r\u{00fc}n') continue;

      products.add(
        XRexParsedProduct(
          name: name,
          price: '',
          oldPrice: '',
          description: 'Fiyats\u{0131}z \u{00fc}r\u{00fc}n tespiti',
          category: _inferCategory(name),
          sourceRect: _unionRects(group.map((e) => e.boundingBox).toList()),
          confidence: 0.5,
          sourceLines: group.map((e) => e.text).toList(),
          warnings: const ['Fiyat bulunamad\u{0131}.'],
          origin: 'visual_ocr_priceless',
          priceAmount: null,
        ),
      );
    }

    return products;
  }

  List<XRexParsedProduct> _parseByCoordinates(List<_LineCandidate> lines) {
    final products = <XRexParsedProduct>[];
    final seenPriceKeys = <String>{};
    final usedContentKeys = <String>{};

    // 1. Extract all potential prices first
    final priceLines =
        lines.where((line) => _extractPrice(line.text) != null).toList();
    // Sort prices: Top-to-bottom, then left-to-right
    priceLines.sort((a, b) {
      if ((a.centerY - b.centerY).abs() > 30) {
        return a.centerY.compareTo(b.centerY);
      }
      return a.centerX.compareTo(b.centerX);
    });

    for (final priceLine in priceLines) {
      if (seenPriceKeys.contains(priceLine.key)) continue;

      final price = _extractPrice(priceLine.text);
      if (price == null) continue;
      final priceAmount = _parseNumericPrice(price);

      // Find old price line near this price line
      _LineCandidate? oldPriceLine;
      for (final other in priceLines) {
        if (other.key == priceLine.key) continue;
        final vDist = (other.centerY - priceLine.centerY).abs();
        final hDist = (other.centerX - priceLine.centerX).abs();
        if (vDist < 60 && hDist < 80) {
          final otherAmount = _parseNumericPrice(other.text) ?? 0.0;
          final thisAmount = priceAmount ?? 0.0;
          if (otherAmount > thisAmount || otherAmount == 0.0) {
            oldPriceLine = other;
            break;
          }
        }
      }

      // 2. Find product name candidates ABOVE this price tag
      // In supermarket shelves, price is almost always BELOW the product.
      final candidatesAbove =
          lines.where((l) {
            if (l.key == priceLine.key || usedContentKeys.contains(l.key)) {
              return false;
            }
            if (_extractPrice(l.text) != null) return false;
            if (_isNoiseLine(l.text)) return false;

            // Must be above and within a horizontal "corridor"
            final isAbove =
                l.centerY < priceLine.centerY &&
                (priceLine.centerY - l.centerY) < 450;
            final hDist = (l.centerX - priceLine.centerX).abs();
            final corridorWidth =
                math.max(l.boundingBox.width, priceLine.boundingBox.width) *
                    0.8 +
                50;

            return isAbove && hDist < corridorWidth;
          }).toList();

      // Sort by proximity to the price (bottom-up)
      candidatesAbove.sort((a, b) => b.centerY.compareTo(a.centerY));

      // 3. Look for Brand (often slightly further away or repeated)
      final brandLine =
          lines.where((l) {
            final isBrand = _isBrandName(l.text);
            if (!isBrand) return false;
            final isNear =
                (l.centerX - priceLine.centerX).abs() < 200 &&
                (priceLine.centerY - l.centerY) < 600;
            return isNear;
          }).toList();

      String brandPrefix = "";
      if (brandLine.isNotEmpty) {
        brandLine.sort(
          (a, b) => (a.centerY - priceLine.centerY).abs().compareTo(
            (b.centerY - priceLine.centerY).abs(),
          ),
        );
        brandPrefix = brandLine.first.text;
      }

      // Construct name from lines closest to price
      final sameLineName = priceLine.text.replaceFirst(price, '').trim();
      final selectedLines = candidatesAbove.take(3).toList().reversed.toList();
      String name = _buildName(sameLineName, selectedLines);

      if (brandPrefix.isNotEmpty &&
          !name.toLowerCase().contains(brandPrefix.toLowerCase())) {
        name = "$brandPrefix $name";
      }

      if (name == "İsimsiz ürün" || name.isEmpty) {
        // Fallback: use text on the same line as price if name is still empty
        final sameLine =
            lines
                .where(
                  (l) =>
                      l.key != priceLine.key &&
                      (l.centerY - priceLine.centerY).abs() < 20,
                )
                .toList();
        if (sameLine.isNotEmpty) {
          name = _buildName(name, sameLine);
        }
      }

      for (final l in selectedLines) {
        usedContentKeys.add(l.key);
      }
      seenPriceKeys.add(priceLine.key);
      if (oldPriceLine != null) {
        seenPriceKeys.add(oldPriceLine.key);
      }

      name = XRexProductTextNormalizer.normalizeProductName(name);
      final hasValidName = name.trim().isNotEmpty && name != '\u{0130}simsiz \u{00fc}r\u{00fc}n';
      final category = _inferCategory("$name ${priceLine.text}");
      final warnings = <String>[
        if (!hasValidName) '\u{00dc}r\u{00fc}n ad\u{0131} belirsiz.',
        if (_isSuspiciousPriceLine(priceLine.text)) 'Fiyat kontrol gerekli.',
      ];

      products.add(
        XRexParsedProduct(
          name: hasValidName ? name : '\u{0130}simsiz \u{00fc}r\u{00fc}n',
          price: price,
          oldPrice: oldPriceLine != null ? oldPriceLine.text : '',
          description: "Raf konumu tespiti",
          category: category,
          sourceRect: _unionRects([
            ...selectedLines.map((e) => e.boundingBox),
            priceLine.boundingBox,
            if (oldPriceLine != null) oldPriceLine.boundingBox,
          ]),
          confidence: hasValidName && warnings.isEmpty ? 0.90 : 0.58,
          sourceLines: [
            ...selectedLines.map((e) => e.text),
            priceLine.text,
            if (oldPriceLine != null) oldPriceLine.text,
          ],
          warnings: warnings,
          origin: 'visual_ocr',
          priceAmount: priceAmount?.toDouble(),
        ),
      );
    }

    final unpairedCandidates =
        lines.where((line) {
          if (usedContentKeys.contains(line.key)) return false;
          if (_extractPrice(line.text) != null) return false;
          if (_isNoiseLine(line.text)) return false;

          final cleanName = XRexProductTextNormalizer.cleanCandidateLine(
            line.text,
          );
          if (cleanName.isEmpty) return false;

          final hasNearbyPrice = priceLines.any((priceLine) {
            final verticalDistance = (priceLine.centerY - line.centerY).abs();
            final horizontalDistance = (priceLine.centerX - line.centerX).abs();
            return verticalDistance < 180 && horizontalDistance < 180;
          });

          return !hasNearbyPrice;
        }).toList();

    for (final candidate in unpairedCandidates) {
      final name = XRexProductTextNormalizer.normalizeProductName(
        candidate.text,
      );
      if (name.isEmpty) continue;
      products.add(
        XRexParsedProduct(
          name: name,
          price: '',
          oldPrice: '',
          description: 'Fiyats\u{0131}z \u{00fc}r\u{00fc}n aday\u{0131}',
          category: _inferCategory(name),
          sourceRect: candidate.boundingBox,
          confidence: 0.45,
          sourceLines: [candidate.text],
          warnings: const ['Fiyat okunamad\u{0131}. Kontrol gerekli.'],
          origin: 'visual_ocr_candidate',
          priceAmount: null,
        ),
      );
    }

    return products;
  }

  bool _isBrandName(String text) {
    return XRexProductTextNormalizer.hasKnownBrand(text);
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
    if (primary.isEmpty && joined.isEmpty) return '\u{0130}simsiz \u{00fc}r\u{00fc}n';

    final name = primary.isNotEmpty ? '$primary $joined'.trim() : joined;
    final normalized = XRexProductTextNormalizer.normalizeProductName(name);
    return normalized.isEmpty ? '\u{0130}simsiz \u{00fc}r\u{00fc}n' : normalized;
  }

  String? _extractPrice(String text) {
    return XRexPriceParser.extractPrice(text);
  }

  num? _parseNumericPrice(String value) {
    return XRexPriceParser.parseAmount(value);
  }

  String _cleanProductName(String value) {
    return XRexProductTextNormalizer.cleanCandidateLine(value);
  }

  bool _isSuspiciousPriceLine(String value) {
    final lower = value.toLowerCase();
    return lower.contains('kim seni düşünür') ||
        lower.contains('indirim') ||
        lower.contains('kampanya') ||
        lower.contains('kupon');
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
      'kitapl\u{0131}k',
      'gard\u{0131}rop',
    ])) {
      return 'Mobilya';
    }
    if (_containsAny(normalized, [
      'krem',
      'parf\u{00fc}m',
      '\u{015f}ampuan',
      'kozmetik',
      'ruj',
      'oje',
      'maskara',
      'far',
      'fond\u{00f6}ten',
      'all\u{0131}k',
      'serum',
      'losyon',
      'makyaj',
      'sabun',
      'du\u{015f} jeli',
    ])) {
      return 'Kozmetik';
    }
    if (_containsAny(normalized, [
      '\u{00e7}orap',
      'pijama',
      'elbise',
      'g\u{00f6}mlek',
      'pantolon',
      'ayakkab\u{0131}',
      'mont',
      'tak\u{0131}m',
      'ceket',
      'kaban',
      'kazak',
      'h\u{0131}rka',
      'ti\u{015f}\u{00f6}rt',
      'yelek',
      'etek',
      'bluz',
      '\u{015f}ort',
      'tayt',
      'i\u{00e7} giyim',
      'giyim',
    ])) {
      return 'Giyim';
    }
    if (_containsAny(normalized, [
      'g\u{00f6}zl\u{00fc}k',
      'g\u{00f6}zl\u{00fc}\u{011f}',
      'lens',
      '\u{00e7}er\u{00e7}eve',
      'optik',
    ])) {
      return 'Gözlük';
    }
    if (_containsAny(normalized, [
      'matkap',
      'vida',
      'anahtar',
      'h\u{0131}rdavat',
      'pense',
      '\u{00e7}eki\u{00e7}',
      'tornavida',
      'testere',
      'alet \u{00e7}antas\u{0131}',
      'somun',
      'c\u{0131}vata',
      '\u{00e7}ivi',
    ])) {
      return 'Hırdavat';
    }
    if (_containsAny(normalized, [
      'defter',
      'kalem',
      'kitap',
      'k\u{0131}rtasiye',
      'silgi',
      'cetvel',
      'boya',
      'makas',
      'z\u{0131}mba',
      'dosya',
      'klas\u{00f6}r',
      'ajanda',
    ])) {
      return 'Kırtasiye';
    }
    if (_containsAny(normalized, [
      '\u{00e7}ay',
      'baharat',
      'aktar',
      'kekik',
      'nane',
      'zencefil',
      'zerde\u{00e7}al',
      '\u{0131}hlamur',
      'ada\u{00e7}ay\u{0131}',
      'kimyon',
      'karabiber',
      'papatya',
    ])) {
      return 'Aktar ürünleri';
    }
    if (_containsAny(normalized, [
      'bebek',
      'araba',
      'lego',
      'oyuncak',
      'barbie',
      'puzzle',
      'pelu\u{015f}',
    ])) {
      return 'Oyuncak';
    }
    if (_containsAny(normalized, [
      'elma',
      'muz',
      'domates',
      'manav',
      'sebze',
      'meyve',
      'limon',
      'patates',
      'so\u{011f}an',
      'portakal',
      '\u{00e7}ilek',
    ])) {
      return 'Manav';
    }
    if (_containsAny(normalized, [
      'yast\u{0131}k',
      'yorgan',
      'nevresim',
      'havlu',
      '\u{00e7}ar\u{015f}af',
      'battaniye',
      'tekstil',
      'perde',
    ])) {
      return 'Ev tekstili';
    }
    if (_containsAny(normalized, [
      'bardak',
      'tabak',
      'tencere',
      'z\u{00fc}ccaciye',
      '\u{00e7}atal',
      'ka\u{015f}\u{0131}k',
      'kase',
      'fincan',
      'tava',
    ])) {
      return 'Züccaciye';
    }
    if (_containsAny(normalized, [
      'k\u{00fc}pe',
      'kolye',
      'y\u{00fc}z\u{00fc}k',
      'saat',
      '\u{00e7}anta',
      'aksesuar',
      'bileklik',
      'toka',
      'kemer',
    ])) {
      return 'Aksesuar';
    }
    return 'Genel';
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
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
    if (_onlyDigitsPattern.hasMatch(normalized)) return true;

    // Reject lines with too many non-alphanumeric chars
    final nonAlphaNumCount =
        normalized.replaceAll(_turkishAlphaNumericPattern, '').length;
    if (nonAlphaNumCount > normalized.length * 0.4) return true;

    // Pure symbol checks
    if (normalized == '\$' || normalized == '₺' || normalized == 'tl') {
      return true;
    }

    if (_onlySymbolsPattern.hasMatch(normalized)) return true;
    if (_timePattern.hasMatch(normalized)) return true;
    if (normalized.contains('★') || normalized.contains('⭐')) return true;

    const noiseTerms = [
      'arama',
      'ara',
      'sepet',
      'favori',
      'favoriler',
      'takip',
      'kargo',
      'teslimat',
      'kupon',
      'taksit',
      'puan',
      'yorum',
      'ana sayfa',
      't\u{00fc}m \u{00fc}r\u{00fc}nler',
      'f\u{0131}rsat',
      'sat\u{0131}c\u{0131}',
      'ma\u{011f}azada ara',
      'video',
      'en \u{00e7}ok ziyaret',
      'avantajl\u{0131} \u{00fc}r\u{00fc}n',
      'men\u{00fc}',
      'koleksiyon',
      't\u{0131}kla',
      'kampanya',
      'payla\u{015f}',
      'be\u{011f}en',
      'detay',
      'indirim',
      'se\u{00e7}enek',
      'kdv',
      'dahil',
      'stokta',
      't\u{00fc}kendi',
      'h\u{0131}zl\u{0131} g\u{00f6}nderim',
      'ayn\u{0131} g\u{00fc}n',
      'kargo bedava',
      'adet',
      'paket',
      'yeni', 'pop\u{00fc}ler', 'stok', 'fiyat',
      // English noise words
      'shipping',
      'delivery',
      'coupon',
      'rating',
      'review',
      'search',
      'menu',
      'cart',
      'free', 'discount', 'details', 'item', 'stars', 'buy', 'now', 'add',
    ];

    return noiseTerms.any(
      (term) =>
          normalized == term ||
          normalized.contains(' $term') ||
          normalized.contains('$term '),
    );
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
