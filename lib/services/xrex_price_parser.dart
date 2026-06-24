class XRexPriceParser {
  XRexPriceParser._();

  static final RegExp pricePattern = RegExp(
    r'(?:sepette\s*)?(?:(?:₺|TL|TRY)\s*)?(?:\d{1,3}(?:[.,\s]\d{3})*|\d{1,9})(?:[.,]\d{1,2})?\s*(?:₺|TL|TRY|tl|try)?',
    caseSensitive: false,
  );

  static String? extractPrice(String text) {
    // Some OCR errors read '70,00' as '70. 00' or similar
    final sanitizedText = text.replaceAll(RegExp(r'\s(?=\d{2}(?!\d))'), '');
    final match = pricePattern.firstMatch(sanitizedText);
    final value = match?.group(0)?.trim();
    if (value == null || value.isEmpty) return null;
    return looksLikePrice(value, sanitizedText) ? value : null;
  }

  static bool looksLikePrice(String value, String fullLine) {
    final normalizedLine = fullLine.toLowerCase();
    final hasCurrency =
        normalizedLine.contains('tl') ||
        normalizedLine.contains('try') ||
        normalizedLine.contains('₺') ||
        normalizedLine.contains('\$');

    if (RegExp(r'\d{1,2}:\d{2}').hasMatch(normalizedLine)) return false;
    if (normalizedLine.contains('puan') || normalizedLine.contains('yorum')) {
      return false;
    }
    if (normalizedLine.contains('%')) return false;
    if (normalizedLine.contains('kupon')) return false;
    if (normalizedLine.contains('indirim') && !normalizedLine.contains('sepette')) {
      return false;
    }
    if (normalizedLine.contains('kampanya') && !hasCurrency) {
      return false;
    }
    if (normalizedLine.contains('+') && !hasCurrency) {
      return false;
    }

    final numeric = parseAmount(value);
    if (numeric == null) return false;
    if (hasCurrency) return true;

    return numeric >= 10;
  }

  static num? parseAmount(String rawPrice) {
    final match = pricePattern.firstMatch(rawPrice);
    final source = match?.group(0) ?? rawPrice;

    var normalized = source
        .replaceAll(RegExp(r'sepette|tl|try|₺|\$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return null;

    normalized = normalized.replaceAll(' ', '');
    if (!RegExp(r'\d').hasMatch(normalized)) return null;

    final lastComma = normalized.lastIndexOf(',');
    final lastDot = normalized.lastIndexOf('.');

    if (lastComma != -1 && lastDot != -1) {
      final decimalSeparator = lastComma > lastDot ? ',' : '.';
      final thousandsSeparator = decimalSeparator == ',' ? '.' : ',';
      normalized = normalized.replaceAll(thousandsSeparator, '');
      if (decimalSeparator == ',') {
        normalized = normalized.replaceAll(',', '.');
      }
    } else if (lastComma != -1 || lastDot != -1) {
      final separator = lastComma != -1 ? ',' : '.';
      final parts = normalized.split(separator);
      if (parts.length > 2) {
        normalized = normalized.replaceAll(separator, '');
      } else if (parts.length == 2) {
        final fractionalLength = parts.last.length;
        if (fractionalLength == 3) {
          normalized = normalized.replaceAll(separator, '');
        } else if (fractionalLength == 1 || fractionalLength == 2) {
          if (separator == ',') {
            normalized = normalized.replaceAll(',', '.');
          }
        } else {
          normalized = normalized.replaceAll(separator, '');
        }
      }
    }

    final parsed = num.tryParse(normalized);
    if (parsed == null) return null;
    if (parsed % 1 == 0) return parsed.toInt();
    return parsed;
  }
}
