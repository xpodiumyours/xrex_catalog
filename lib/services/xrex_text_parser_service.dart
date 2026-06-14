import '../models/xrex_parsed_product.dart';
import '../models/xrex_text_candidate.dart';

class XRexTextParserService {
  const XRexTextParserService();

  static final RegExp _pricePattern = RegExp(
    r'(?:(?:₺|TL|TRY)\s*)?\d{1,6}(?:[.,]\d{1,2})?\s*(?:₺|TL|TRY|tl|try)?',
    caseSensitive: false,
  );

  List<XRexTextCandidate> parse(String rawText) {
    final normalized = rawText.trim();
    if (normalized.isEmpty) return const [];

    final candidates = <XRexTextCandidate>[];
    final seen = <String>{};

    for (final match in _pricePattern.allMatches(normalized)) {
      final value = match.group(0)?.trim();
      if (value == null || value.isEmpty) continue;

      final hasDigit = RegExp(r'\d').hasMatch(value);
      if (!hasDigit) continue;

      final key = 'price:${value.toLowerCase()}';
      if (!seen.add(key)) continue;

      candidates.add(
        XRexTextCandidate(
          id: 'price_${match.start}_${match.end}',
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
      final cleaned = line.replaceAll(_pricePattern, '').trim();
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
    final nameBuffer = <String>[];
    XRexParsedProduct? pendingProduct;

    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      final priceMatch = _pricePattern.firstMatch(line);
      if (priceMatch == null) {
        if (_isNoiseLine(line)) continue;

        if (pendingProduct != null && pendingProduct.description.isEmpty) {
          final nextLine = index + 1 < lines.length ? lines[index + 1] : null;
          final nextLineHasPrice =
              nextLine != null && _pricePattern.hasMatch(nextLine);
          if (nextLineHasPrice) {
            products.add(pendingProduct);
            pendingProduct = null;
            nameBuffer
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

        nameBuffer.add(line);
        if (nameBuffer.length > 2) {
          nameBuffer.removeAt(0);
        }
        continue;
      }

      if (pendingProduct != null) {
        products.add(pendingProduct);
        pendingProduct = null;
      }

      final price = priceMatch.group(0)?.trim() ?? '';
      final sameLineName = line.replaceFirst(_pricePattern, '').trim();
      final name = _buildName(sameLineName, nameBuffer);
      pendingProduct = XRexParsedProduct(
        name: name,
        price: price,
        description: '',
      );
      nameBuffer.clear();
    }

    if (pendingProduct != null) {
      products.add(pendingProduct);
    }

    return products;
  }

  List<String> _cleanLines(String rawText) {
    return rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((line) => line.isNotEmpty)
        .toList();
  }

  String _buildName(String sameLineName, List<String> nameBuffer) {
    if (sameLineName.isNotEmpty) return sameLineName;
    final bufferedName =
        nameBuffer.where((line) => !_isNoiseLine(line)).join(' ').trim();
    if (bufferedName.isNotEmpty) return bufferedName;
    return 'İsimsiz ürün';
  }

  bool _isNoiseLine(String line) {
    final normalized = line.trim().toLowerCase();
    if (normalized.length < 2) return true;
    if (RegExp(r'^\W+$').hasMatch(normalized)) return true;
    if (RegExp(r'^(tl|try|₺)$', caseSensitive: false).hasMatch(normalized)) {
      return true;
    }
    return false;
  }
}
