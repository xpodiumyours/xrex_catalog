// ignore_for_file: deprecated_member_use

class XRexProductTextNormalizer {
  XRexProductTextNormalizer._();

  static const List<String> knownBrands = [
    '\u{00dc}lker',
    'Biscolata',
    'Dankek',
    'Biskrem',
    'Halley',
    '\u{00e7}izi',
    'Rulokat',
    'Luppo',
    'Kekstra',
    'Olala',
    'Magma',
    'Nutymax',
    'Probis',
    '\u{00c7}okoprens',
  ];

  static String normalizeProductName(String value) {
    var normalized = normalizeOcrText(value);
    normalized =
        normalized
            .replaceAll(_namelessProductPattern, '')
            .replaceAll(
              _junkKeywordsPattern,
              '',
            )
            .replaceAll(_multipleSpacesPattern, ' ')
            .trim();

    final parts =
        normalized.split(' ').where((part) => !_isJunkToken(part)).toList();
    final compactParts = <String>[];
    for (final part in parts) {
      if (compactParts.isNotEmpty &&
          compactParts.last.toLowerCase() == part.toLowerCase()) {
        continue;
      }
      compactParts.add(part);
    }
    normalized = compactParts.join(' ').trim();

    if (normalized.length < 3) return '';
    if (!RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ]').hasMatch(normalized)) return '';
    final letters = normalized.replaceAll(RegExp(r'[^a-zA-ZğüşıöçĞÜŞİÖÇ]'), '');
    if (letters.length > 3 && !RegExp(r'[aeiouöüıiAEIOUÖÜİI]').hasMatch(letters)) {
      if (!hasKnownBrand(normalized)) return '';
    }
    return normalized;
  }

  static String cleanCandidateLine(String value) {
    final normalized = normalizeProductName(value);
    if (normalized.isEmpty) return '';
    if (_isNoiseLine(normalized)) return '';
    return normalized;
  }

  static final RegExp _pipeUnderscorePattern = RegExp(r'[_|]+');
  static final RegExp _multipleSpacesPattern = RegExp(r'\s+');
  static final RegExp _namelessProductPattern = RegExp(
    '(?:^|\\s)[i\u{0131}\u{0130}i\u{0307}]simsiz\\s+[u\u{00fc}]r[u\u{00fc}]n(?:\$|\\s)',
    caseSensitive: false,
  );
  static final RegExp _junkKeywordsPattern = RegExp(
    r'\b(fiyat|stok|paket|adet)\b',
    caseSensitive: false,
  );
  static final RegExp _nonAlphaNumericPattern = RegExp(r'[^a-z0-9]+');
  static final RegExp _allDigitsPattern = RegExp(r'^\d+$');
  static final RegExp _turkishNonAlphaPattern = RegExp(
    '[^a-z\u{011f}\u{00fc}\u{015f}\u{0131}\u{00f6}\u{00e7}]',
  );
  static final RegExp _turkishVowelsPattern = RegExp(
    '[aeiou\u{00f6}\u{00fc}\u{0131}i]',
  );

  static String normalizeOcrText(String value) {
    var text =
        value
            .replaceAll(_pipeUnderscorePattern, ' ')
            .replaceAll(_multipleSpacesPattern, ' ')
            .trim();

    // Word replacements that may start/end with Turkish characters or ASCII
    // To handle Turkish case conversion correctly and word boundaries, we map them carefully.
    text = text.replaceAllMapped(
      RegExp('(^|\\s)(ulker|[\u{00fc}\u{00dc}]lker|[ij1\u{0130}]lker|iker)(?=\\b)', caseSensitive: false),
      (match) => '${match[1]}\u{00dc}lker',
    );
    text = text.replaceAllMapped(
      RegExp('\\b(biscolata|biscolta|aiscolata|spscoki)\\b', caseSensitive: false),
      (match) => 'Biscolata',
    );
    text = text.replaceAllMapped(
      RegExp('\\b(dankek|darikek|danlcpallay|dankel|dankck|dinkek)\\b', caseSensitive: false),
      (match) => 'Dankek',
    );
    text = text.replaceAllMapped(
      RegExp('\\b(biskrem|biskremi|biskremni)\\b', caseSensitive: false),
      (match) => 'Biskrem',
    );
    text = text.replaceAllMapped(
      RegExp('\\b(reulokat|reulokats|rleikat|ruloke|rulokat[s]?)\\b', caseSensitive: false),
      (match) => 'Rulokat',
    );
    text = text.replaceAllMapped(
      RegExp('\\b(p9malk|payasm[\u{0131}iI\u{0130}]l[\u{0131}iI\u{0130}]k|payla[\u{015f}\u{015e}]m[\u{0131}iI\u{0130}]l[\u{0131}iI\u{0130}]k|ajsmiln)\\b', caseSensitive: false),
      (match) => 'Payla\u{015f}mal\u{0131}k',
    );
    text = text.replaceAllMapped(
      RegExp('\\b(nigh|n[\u{0131}iI\u{0130}]ght)\\b', caseSensitive: false),
      (match) => 'Night',
    );
    text = text.replaceAllMapped(
      RegExp('\\b(brounie|brown[\u{0131}iI\u{0130}]e)\\b', caseSensitive: false),
      (match) => 'Brownie',
    );
    text = text.replaceAllMapped(
      RegExp('\\b(sfarz|staz|star2)\\b', caseSensitive: false),
      (match) => 'Starz',
    );
    text = text.replaceAllMapped(
      RegExp('\\b(kekstre|kekstr[a]?)\\b', caseSensitive: false),
      (match) => 'Kekstra',
    );
    text = text.replaceAllMapped(
      RegExp('\\b(nutymax|nutymaxx)\\b', caseSensitive: false),
      (match) => 'Nutymax',
    );
    text = text.replaceAllMapped(
      RegExp('(^|\\s)(citir|[\u{00e7}\u{00c7}]itir|[\u{00e7}\u{00c7}][\u{0131}iI\u{0130}]t[\u{0131}iI\u{0130}]r)(?=\\b)', caseSensitive: false),
      (match) => '${match[1]}\u{00c7}\u{0131}t\u{0131}r',
    );
    text = text.replaceAllMapped(
      RegExp('(^|\\s)(cizi|[\u{00e7}\u{00c7}]izi|[\u{00e7}\u{00c7}]iz[\u{0131}iI\u{0130}])(?=\\b)', caseSensitive: false),
      (match) => '${match[1]}\u{00c7}izi',
    );
    text = text.replaceAllMapped(
      RegExp('\\b(olala|olala souffle|opla surle)\\b', caseSensitive: false),
      (match) => 'Olala',
    );

    return text.replaceAll(_multipleSpacesPattern, ' ').trim();
  }

  static String dedupeKey(String value) {
    final normalized =
        normalizeProductName(value)
            .toLowerCase()
            .replaceAll('\u{011f}', 'g')
            .replaceAll('\u{00fc}', 'u')
            .replaceAll('\u{015f}', 's')
            .replaceAll('\u{0131}', 'i')
            .replaceAll('\u{00f6}', 'o')
            .replaceAll('\u{00e7}', 'c')
            .replaceAll(_nonAlphaNumericPattern, ' ')
            .trim();

    final tokens =
        normalized
            .split(' ')
            .where((token) => token.length > 2 && !_isJunkToken(token))
            .take(4)
            .toList();

    return tokens.join(' ');
  }

  static bool hasKnownBrand(String value) {
    final normalized = normalizeOcrText(value).toLowerCase();
    return knownBrands.any((brand) => normalized.contains(brand.toLowerCase()));
  }

  static bool _isJunkToken(String token) {
    final value = token.trim().toLowerCase();
    if (value.isEmpty) return true;
    if (value == 'tl' || value == 'try') return true;
    if (value == 'pakef' || value == 'pakel' || value == 'ken') return true;
    if (_allDigitsPattern.hasMatch(value)) return true;
    if (value.length == 1 && !hasKnownBrand(value)) return true;
    final letters = value.replaceAll(_turkishNonAlphaPattern, '');
    if (letters.length >= 4 && !_turkishVowelsPattern.hasMatch(letters)) {
      return true;
    }
    return false;
  }

  static bool _isNoiseLine(String value) {
    final lower = value.toLowerCase();
    const noise = [
      'kim seni düşünür',
      'indirim',
      'kampanya',
      'kargo',
      'kupon',
      'daha fazla',
      'stok',
      'raf',
      'etiket',
    ];
    return noise.any(lower.contains);
  }
}
