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
    final lines =
        rawText
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
    if (lines.isEmpty) return const [];

    final products = <XRexParsedProduct>[];
    XRexParsedProduct? pending;

    for (final line in lines) {
      final priceMatch = _pricePattern.firstMatch(line);
      if (priceMatch == null) {
        if (pending != null && pending.description.trim().isEmpty) {
          pending = XRexParsedProduct(
            name: pending.name,
            price: pending.price,
            description: line,
          );
        }
        continue;
      }

      if (pending != null) {
        products.add(pending);
      }

      final price = priceMatch.group(0)?.trim() ?? '';
      final name = line.replaceFirst(_pricePattern, '').trim();
      pending = XRexParsedProduct(
        name: name.isEmpty ? 'İsimsiz ürün' : name,
        price: price,
        description: '',
      );
    }

    if (pending != null) {
      products.add(pending);
    }

    return products;
  }
}
