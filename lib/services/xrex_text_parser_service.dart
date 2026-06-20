import '../models/xrex_parsed_product.dart';
import '../models/xrex_text_candidate.dart';
import 'xrex_price_parser.dart';

class XRexTextParserService {
  const XRexTextParserService();

  static const int _maxNameWindowSize = 5;
  static const int _maxCombinedNameLines = 3;
  static const int _longNameThreshold = 80;

  List<XRexTextCandidate> parse(String rawText) {
    final normalized = rawText.trim();
    if (normalized.isEmpty) return const [];

    final candidates = <XRexTextCandidate>[];
    final seen = <String>{};

    for (final line in normalized.split(RegExp(r'\r?\n'))) {
      final value = XRexPriceParser.extractPrice(line);
      if (value == null || value.isEmpty) continue;

      final key = 'price:${value.toLowerCase()}';
      if (!seen.add(key)) continue;

      candidates.add(
        XRexTextCandidate(
          id: 'price_${candidates.length}_${value.length}',
          label: 'Fiyat adayı',
          value: value,
          type: XRexTextCandidateType.price,
        ),
      );
    }

    final textLines = normalized
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.length >= 3)
        .take(6);

    for (final line in textLines) {
      final extractedPrice = XRexPriceParser.extractPrice(line);
      final cleaned = extractedPrice == null
          ? line
          : line.replaceFirst(extractedPrice, '').trim();
      if (cleaned.length < 3) continue;

      final key = 'text:${cleaned.toLowerCase()}';
      if (!seen.add(key)) continue;

      candidates.add(
        XRexTextCandidate(
          id: 'text_${candidates.length}_${cleaned.length}',
          label: 'Metin adayı',
          value: cleaned,
          type: XRexTextCandidateType.text,
        ),
      );
    }

    return candidates;
  }

  List<XRexParsedProduct> parseProducts(String rawText) {
    final lines = _cleanLines(rawText);
    if (lines.isEmpty) return const [];

    final products = <XRexParsedProduct>[];
    final nameWindow = <String>[];
    XRexParsedProduct? pendingProduct;

    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      final price = XRexPriceParser.extractPrice(line);
      if (price == null) {
        if (_isNoiseLine(line)) continue;

        if (pendingProduct != null && pendingProduct.description.isEmpty) {
          final nextLine = index + 1 < lines.length ? lines[index + 1] : null;
          final nextLineHasPrice =
              nextLine != null &&
              XRexPriceParser.extractPrice(nextLine) != null;
          if (nextLineHasPrice) {
            products.add(pendingProduct);
            pendingProduct = null;
            nameWindow
              ..clear()
              ..add(line);
            continue;
          }

          pendingProduct = XRexParsedProduct(
            name: pendingProduct.name,
            price: pendingProduct.price,
            description: line,
          );
          continue;
        }

        nameWindow.add(line);
        if (nameWindow.length > _maxNameWindowSize) {
          nameWindow.removeAt(0);
        }
        continue;
      }

      if (pendingProduct != null) {
        products.add(pendingProduct);
        pendingProduct = null;
      }

      final sameLineName = line.replaceFirst(price, '').trim();
      final selection = _selectBestName(sameLineName, nameWindow);
      pendingProduct = XRexParsedProduct(
        name: selection.name,
        price: price,
        description: '',
        sourceLines: selection.sourceLines,
        warnings: selection.warnings,
        origin: 'text_parser',
      );
      nameWindow.clear();
    }

    if (pendingProduct != null) {
      products.add(pendingProduct);
    }

    return products;
  }

  List<String> _cleanLines(String rawText) {
    return rawText
        .split(RegExp(r'\r?\n'))
        .map(_normalizeWhitespace)
        .where((line) => line.isNotEmpty)
        .toList();
  }

  _NameSelectionResult _selectBestName(String sameLineName, List<String> nameWindow) {
    final normalizedSameLineName = _normalizeWhitespace(sameLineName);
    if (normalizedSameLineName.isNotEmpty && !_isNoiseLine(normalizedSameLineName)) {
      return _NameSelectionResult(
        name: normalizedSameLineName,
        sourceLines: [normalizedSameLineName],
        warnings: _buildNameWarnings([normalizedSameLineName], normalizedSameLineName),
      );
    }

    final candidates =
        nameWindow
            .where((line) => !_isNoiseLine(line))
            .toList();
    if (candidates.isEmpty) {
      return const _NameSelectionResult(
        name: 'İsimsiz ürün',
        sourceLines: [],
        warnings: ['Ürün adı güvenli seçilemedi.'],
      );
    }

    var bestIndex = 0;
    var bestScore = -9999;
    for (var i = 0; i < candidates.length; i += 1) {
      final distanceFromPrice = candidates.length - 1 - i;
      final score = _scoreNameLine(candidates[i], distanceFromPrice);
      if (score >= bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    final selectedLines = <String>[candidates[bestIndex]];

    for (var i = bestIndex - 1; i >= 0; i -= 1) {
      final candidate = candidates[i];
      if (!_shouldPrependNameLine(candidate, selectedLines.first)) {
        continue;
      }
      selectedLines.insert(0, candidate);
      if (selectedLines.length >= _maxCombinedNameLines) break;
    }

    final name = _normalizeWhitespace(selectedLines.join(' '));
    return _NameSelectionResult(
      name: name.isEmpty ? 'İsimsiz ürün' : name,
      sourceLines: selectedLines,
      warnings: _buildNameWarnings(selectedLines, name),
    );
  }

  List<String> _buildNameWarnings(List<String> selectedLines, String name) {
    final warnings = <String>[];
    if (selectedLines.length >= _maxCombinedNameLines || name.length > _longNameThreshold) {
      warnings.add('Ürün adı uzun, kontrol önerilir.');
    }
    return warnings;
  }

  bool _shouldPrependNameLine(String candidate, String anchor) {
    if (_isBrandLike(candidate)) return true;

    final candidateWords = candidate.split(' ').where((part) => part.isNotEmpty).length;
    final anchorWords = anchor.split(' ').where((part) => part.isNotEmpty).length;
    if (candidateWords <= 3 && anchorWords <= 8) return true;
    if (candidateWords <= 8 && anchorWords <= 8 && candidate.length <= 60) {
      return true;
    }

    return false;
  }

  int _scoreNameLine(String line, int distanceFromPrice) {
    var score = 0;
    final normalized = _normalizeWhitespace(line);
    final letterCount = RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').allMatches(normalized).length;
    final digitCount = RegExp(r'\d').allMatches(normalized).length;
    final wordCount = normalized.split(' ').where((part) => part.isNotEmpty).length;

    if (letterCount >= 3) score += 5;
    if (digitCount == 0) {
      score += 2;
    } else {
      score -= 2;
    }
    if (wordCount >= 2 && wordCount <= 8) score += 2;
    if (normalized.length >= 5 && normalized.length <= 60) score += 2;
    if (_isBrandLike(normalized)) score += 1;
    score += (3 - distanceFromPrice).clamp(0, 3);

    return score;
  }

  bool _isBrandLike(String line) {
    final normalized = _normalizeWhitespace(line);
    if (normalized.isEmpty) return false;

    final words = normalized.split(' ').where((part) => part.isNotEmpty).toList();
    if (words.length > 3) return false;

    final uppercaseLetters =
        RegExp(r'[A-ZÇĞİÖŞÜ]').allMatches(normalized).length;
    final lowercaseLetters =
        RegExp(r'[a-zçğıöşü]').allMatches(normalized).length;

    return uppercaseLetters >= 2 && lowercaseLetters == 0;
  }

  String _normalizeWhitespace(String line) {
    return line.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isNoiseLine(String line) {
    final normalized = _normalizeWhitespace(line).toLowerCase();
    if (normalized.length < 2) return true;
    if (RegExp(r'^\W+$').hasMatch(normalized)) return true;
    if (RegExp(r'^\d+$').hasMatch(normalized)) return true;
    if (RegExp(r'^\d+/\d+$').hasMatch(normalized)) return true;
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(normalized)) return true;
    if (RegExp(r'^(tl|try|₺)$', caseSensitive: false).hasMatch(normalized)) {
      return true;
    }
    if (normalized.contains('%')) return true;
    const noiseTerms = [
      'ana sayfa',
      'mağazada ara',
      'magazada ara',
      'favoriler',
      'favori',
      'ara',
      'kupon',
      'indirim',
      'kampanya',
      'puan',
      'yorum',
      'kargo',
      'teslimat',
      'bedava',
      'taksit',
      'hızlı teslimat',
      'hizli teslimat',
      'video ürün',
      'flash ürün',
      'flaş ürün',
    ];
    if (noiseTerms.any(normalized.contains)) return true;
    return false;
  }
}

class _NameSelectionResult {
  final String name;
  final List<String> sourceLines;
  final List<String> warnings;

  const _NameSelectionResult({
    required this.name,
    required this.sourceLines,
    required this.warnings,
  });
}
