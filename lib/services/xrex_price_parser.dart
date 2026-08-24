// ignore_for_file: deprecated_member_use

class XRexPriceParser {
  XRexPriceParser._();

  static final RegExp pricePattern = RegExp(
    r'(?:sepette\s*)?(?:(?:₺|TL|TRY)\s*)?(?:\d{1,3}(?:[.,\s]\d{3})*|\d{1,9})(?:[.,]\d{1,2})?\s*(?:₺|TL|TRY|tl|try)?',
    caseSensitive: false,
  );

  static final RegExp _spaceDigitPattern = RegExp(r'\s(?=\d{2}(?!\d))');
  static final RegExp _timePattern = RegExp(r'\d{1,2}:\d{2}');
  static final RegExp _currencyJunkPattern = RegExp(r'sepette|tl|try|₺|\$', caseSensitive: false);
  static final RegExp _multipleSpacesPattern = RegExp(r'\s+');
  static final RegExp _digitPresencePattern = RegExp(r'\d');

  static String? extractPrice(String text) {
    // Some OCR errors read '70,00' as '70. 00' or similar
    final sanitizedText = text.replaceAll(_spaceDigitPattern, '');
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

    if (_timePattern.hasMatch(normalizedLine)) return false;
    if (normalizedLine.contains('★') || normalizedLine.contains('⭐')) return false;
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
    
    // Standalone numbers without currency are not prices (e.g., page numbers, quantities)
    if (!hasCurrency) {
      // Reject if the full line is just digits (possibly with spaces)
      final digitsOnly = RegExp(r'^[\d\s]+$').hasMatch(normalizedLine);
      if (digitsOnly) return false;
      // Require minimum amount for prices without currency
      return numeric >= 4;
    }

    return true;
  }

  static num? parseAmount(String rawPrice) {
    final match = pricePattern.firstMatch(rawPrice);
    final source = match?.group(0) ?? rawPrice;

    var normalized = source
        .replaceAll(_currencyJunkPattern, '')
        .replaceAll(_multipleSpacesPattern, ' ')
        .trim();
    if (normalized.isEmpty) return null;

    normalized = normalized.replaceAll(' ', '');
    if (!_digitPresencePattern.hasMatch(normalized)) return null;

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
