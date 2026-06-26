// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/xrex_portfolio_product.dart';

class XRexPortfolioMatch {
  final XRexPortfolioProduct product;
  final double confidence;

  const XRexPortfolioMatch({
    required this.product,
    required this.confidence,
  });
}

class XRexPortfolioService {
  static final XRexPortfolioService _instance = XRexPortfolioService._internal();

  factory XRexPortfolioService() {
    return _instance;
  }

  XRexPortfolioService._internal() {
    _loadDefaults();
    // Silently trigger sync on startup
    initializeDefaultPortfolio();
  }

  static const List<String> defaultPortfolioUrls = [
    'https://docs.google.com/spreadsheets/d/1AaSsspiU69moRaMa-UNIwDQeH0ly9svNZdyhdZsEhak/edit?gid=1495272820#gid=1495272820',
    'https://docs.google.com/spreadsheets/d/1asfAo0EeoicwV04tESwdxX_gX3Jc91tcnlaPGxhif_Q/edit?gid=5937822#gid=5937822',
    'https://docs.google.com/spreadsheets/d/1Qt-AYzB4g-uThPQX1tWmcVHoHLBrXw5J4XCZ8-sW1Kk/edit?gid=1110347743#gid=1110347743',
  ];

  Future<void> initializeDefaultPortfolio() async {
    products.clear();
    for (final url in defaultPortfolioUrls) {
      await syncFromGoogleSheet(url);
    }
  }

  List<XRexPortfolioProduct> products = [];
  String? lastSheetUrl;
  DateTime? lastSyncTime;

  // Pre-load default products matching Turkish markets/local stores
  void _loadDefaults() {
    products = [
      const XRexPortfolioProduct(
        id: 'def_1',
        name: 'Nescafe Xpress Black Roast So\u{011f}uk Kahve',
        category: '\u{0130}\u{00e7}ecekler',
        price: '45.00 TL',
        description: 'Kahve \u{0130}\u{00e7}ece\u{011f}i Taze ve ferahlat\u{0131}c\u{0131}',
        aliases: ['nescafe xpress', 'black roast', 'xpress black'],
      ),
      const XRexPortfolioProduct(
        id: 'def_2',
        name: 'Nescafe Xpress Original So\u{011f}uk Kahve',
        category: '\u{0130}\u{00e7}ecekler',
        price: '45.00 TL',
        description: 'Kahve \u{0130}\u{00e7}ece\u{011f}i Taze ve ferahlat\u{0131}c\u{0131}',
        aliases: ['nescafe xpress', 'original', 'xpress original'],
      ),
      const XRexPortfolioProduct(
        id: 'def_3',
        name: 'Nescafe Xpress Vanilya Latte So\u{011f}uk Kahve',
        category: '\u{0130}\u{00e7}ecekler',
        price: '45.00 TL',
        description: 'Kahve \u{0130}\u{00e7}ece\u{011f}i Taze ve ferahlat\u{0131}c\u{0131}',
        aliases: ['vanilla latte', 'xpress vanilya', 'vanilya latte'],
      ),
      const XRexPortfolioProduct(
        id: 'def_4',
        name: 'Starbucks Frappuccino Coffee',
        category: '\u{0130}\u{00e7}ecekler',
        price: '85.00 TL',
        description: 'Starbucks kalitesiyle \u{015f}işede kahve keyfi',
        aliases: ['starbucks frappuccino', 'frappuccino coffee', 'starbucks'],
      ),
      const XRexPortfolioProduct(
        id: 'def_5',
        name: 'Obsesso Latte So\u{011f}uk Kahve',
        category: '\u{0130}\u{00e7}ecekler',
        price: '40.00 TL',
        description: 'S\u{00fc}tl\u{00fc} ve tatl\u{0131} kahve deneyimi',
        aliases: ['obsesso latte', 'obsesso', 'so\u{011f}uk latte'],
      ),
      const XRexPortfolioProduct(
        id: 'def_6',
        name: 'Obsesso Caramel Macchiato So\u{011f}uk Kahve',
        category: '\u{0130}\u{00e7}ecekler',
        price: '40.00 TL',
        description: 'Karamel aromal\u{0131} so\u{011f}uk kahve',
        aliases: ['obsesso caramel', 'caramel macchiato'],
      ),
      const XRexPortfolioProduct(
        id: 'def_7',
        name: '\u{00dc}lker \u{00c7}izi Kraker',
        category: 'At\u{0131}\u{015f}t\u{0131}rmal\u{0131}k',
        price: '12.00 TL',
        description: 'Tuzlu peynirli kraker',
        aliases: ['cizi', '\u{00e7}izi', 'ulker cizi'],
      ),
      const XRexPortfolioProduct(
        id: 'def_8',
        name: 'Biscolata Starz Kakaolu',
        category: 'At\u{0131}\u{015f}t\u{0131}rmal\u{0131}k',
        price: '18.00 TL',
        description: '\u{00c7}ikolata kapl\u{0131} bisk\u{00fc}vi',
        aliases: ['biscolata', 'starz', 'biscolata starz'],
      ),
    ];
  }

  // Parse Google Sheets URL to export URL
  String? convertToExportUrl(String rawUrl) {
    final sheetIdRegex = RegExp(r'/d/([a-zA-Z0-9-_]+)');
    final sheetIdMatch = sheetIdRegex.firstMatch(rawUrl);
    if (sheetIdMatch == null) return null;

    final sheetId = sheetIdMatch.group(1);
    final gidRegex = RegExp(r'[#&?]gid=([0-9]+)');
    final gidMatch = gidRegex.firstMatch(rawUrl);
    final gid = gidMatch?.group(1);

    if (gid != null) {
      return 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=tsv&gid=$gid';
    }
    return 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=tsv';
  }

  // Fetch TSV content from Google Sheets URL
  Future<bool> syncFromGoogleSheet(String url) async {
    final exportUrl = convertToExportUrl(url);
    if (exportUrl == null) return false;

    try {
      final response = await http.get(Uri.parse(exportUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final tsvContent = utf8.decode(bytes);
        final success = parseTsv(tsvContent);
        if (success) {
          lastSheetUrl = url;
          lastSyncTime = DateTime.now();
        }
        return success;
      }
    } catch (_) {
      // Return false in case of network or parse error
    }
    return false;
  }

  // Fast TSV Parser
  bool parseTsv(String tsvContent) {
    try {
      final lines = tsvContent.split(RegExp(r'\r?\n'));
      if (lines.isEmpty) return false;

      // Extract headers from first line
      final headers = lines[0].split('\t').map((h) => h.trim().toLowerCase()).toList();

      // Find column indexes
      final nameIdx = headers.indexOf('urun_adi');
      final catIdx = headers.indexOf('kategori');
      final descIdx = headers.indexOf('aciklama');
      final matchIdx = headers.indexOf('ocr_eslesme_kelimeleri');

      if (nameIdx == -1) {
        // Essential column 'urun_adi' not found
        return false;
      }

      final newProducts = <XRexPortfolioProduct>[];
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final cells = line.split('\t');
        if (cells.length <= nameIdx) continue;

        final name = cells[nameIdx].trim();
        if (name.isEmpty) continue;

        final category = (catIdx != -1 && cells.length > catIdx) ? cells[catIdx].trim() : 'Genel';
        final description = (descIdx != -1 && cells.length > descIdx) ? cells[descIdx].trim() : '';
        final rawMatches = (matchIdx != -1 && cells.length > matchIdx) ? cells[matchIdx].trim() : '';

        // Aliases list split by comma or semicolon
        final aliases = rawMatches.isNotEmpty
            ? rawMatches
                .split(RegExp(r'[,;]'))
                .map((a) => a.trim().toLowerCase())
                .where((a) => a.isNotEmpty)
                .toList()
            : <String>[];

        newProducts.add(
          XRexPortfolioProduct(
            id: 'sheet_${i}_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            category: category,
            price: '', // Will be updated on OCR match or defaults
            description: description,
            aliases: aliases,
          ),
        );
      }

      if (newProducts.isNotEmpty) {
        // To support syncing multiple sheets/tabs (like beverages, snacks, cleaning products)
        // without overwriting, we append new products and update existing ones.
        final existingNames = products.map((p) => p.name.toLowerCase().trim()).toSet();
        for (final newP in newProducts) {
          final normalizedNewName = newP.name.toLowerCase().trim();
          if (!existingNames.contains(normalizedNewName)) {
            products.add(newP);
          } else {
            // Update existing product details if it already exists
            final idx = products.indexWhere((p) => p.name.toLowerCase().trim() == normalizedNewName);
            if (idx != -1) {
              products[idx] = newP;
            }
          }
        }
        return true;
      }
    } catch (_) {
      // Parser crash protection
    }
    return false;
  }

  // Simplified string for matching (case conversion, accents, special character removal)
  String _simplify(String text) {
    return text
        .toLowerCase()
        .replaceAll('\u{011f}', 'g')
        .replaceAll('\u{011e}', 'g')
        .replaceAll('\u{00fc}', 'u')
        .replaceAll('\u{00dc}', 'u')
        .replaceAll('\u{015f}', 's')
        .replaceAll('\u{015e}', 's')
        .replaceAll('\u{0131}', 'i')
        .replaceAll('\u{0130}', 'i')
        .replaceAll('\u{00f6}', 'o')
        .replaceAll('\u{00d6}', 'o')
        .replaceAll('\u{00e7}', 'c')
        .replaceAll('\u{00c7}', 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Find best match in the portfolio list using Jaro-Winkler Similarity
  XRexPortfolioMatch? findBestMatch(String rawOcrName, {double threshold = 0.72}) {
    final matches = findTopMatches(rawOcrName, limit: 1);
    if (matches.isNotEmpty && matches.first.confidence >= threshold) {
      return matches.first;
    }
    return null;
  }

  // Find nearest product matches in the portfolio list sorted by similarity
  List<XRexPortfolioMatch> findTopMatches(String rawOcrName, {int limit = 3}) {
    final query = _simplify(rawOcrName);
    
    // Master Özellik: Çöp Filtreleri (Garbage Text Filters)
    // 1. En az 4 karakter olmalı
    if (query.length < 4) return const [];
    
    // 2. Sadece rakamlardan oluşuyorsa (Fiyat veya barkod karışması)
    if (RegExp(r'^\d+$').hasMatch(query)) return const [];
    
    // 3. İçinde en az bir sesli harf olmalı (a, e, i, o, u). Yoksa rastgele gürültüdür
    if (!RegExp(r'[aeiou]').hasMatch(query)) return const [];

    final matches = <XRexPortfolioMatch>[];

    for (final prod in products) {
      final sName = _simplify(prod.name);

      // 1. Full string Jaro-Winkler
      final nameSim = jaroWinkler(query, sName);
      var currentMax = nameSim;

      // 2. Advanced token Jaro-Winkler
      final nameAdvSim = computeAdvancedTokenScore(query, sName);
      if (nameAdvSim > currentMax) {
        currentMax = nameAdvSim;
      }

      // 3. Aliases
      for (final alias in prod.aliases) {
        final sAlias = _simplify(alias);
        final aliasSim = jaroWinkler(query, sAlias);
        if (aliasSim > currentMax) {
          currentMax = aliasSim;
        }

        final aliasAdvSim = computeAdvancedTokenScore(query, sAlias);
        if (aliasAdvSim > currentMax) {
          currentMax = aliasAdvSim;
        }
      }

      matches.add(XRexPortfolioMatch(product: prod, confidence: currentMax));
    }

    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    return matches.take(limit).toList();
  }

  // Greedy token-matching algorithm with brand-name suppression and mismatch penalty
  double computeAdvancedTokenScore(String query, String target) {
    final qTokens = query.split(' ').where((t) => t.isNotEmpty).toList();
    final tTokens = target.split(' ').where((t) => t.isNotEmpty).toList();
    if (qTokens.isEmpty || tTokens.isEmpty) return 0.0;

    // Suppress single-word short brand names for long queries
    if (qTokens.length >= 3 && tTokens.length == 1 && target.length < 6) {
      return 0.0;
    }

    // 1. Build all pairs with their Jaro-Winkler similarity
    final pairs = <Map<String, dynamic>>[];
    for (var qIdx = 0; qIdx < qTokens.length; qIdx++) {
      for (var tIdx = 0; tIdx < tTokens.length; tIdx++) {
        final sim = jaroWinkler(qTokens[qIdx], tTokens[tIdx]);
        pairs.add({
          'qIdx': qIdx,
          'tIdx': tIdx,
          'sim': sim,
        });
      }
    }

    // 2. Sort pairs by similarity in descending order
    pairs.sort((a, b) => (b['sim'] as double).compareTo(a['sim'] as double));

    // 3. Greedily match tokens (consume matched tokens)
    final matchedQ = List<bool>.filled(qTokens.length, false);
    final matchedT = List<bool>.filled(tTokens.length, false);
    var matchedCount = 0;
    var sumSim = 0.0;

    for (final pair in pairs) {
      final qIdx = pair['qIdx'] as int;
      final tIdx = pair['tIdx'] as int;
      final sim = pair['sim'] as double;

      if (!matchedQ[qIdx] && !matchedT[tIdx] && sim >= 0.70) {
        matchedQ[qIdx] = true;
        matchedT[tIdx] = true;
        matchedCount++;
        sumSim += sim;
      }
    }

    if (matchedCount == 0) return 0.0;

    // 4. Calculate score with a gentle penalty for unmatched target tokens
    final unmatchedCount = tTokens.length - matchedCount;
    final denominator = matchedCount + 0.5 * unmatchedCount;

    return sumSim / denominator;
  }

  // Pure Jaro-Winkler Similarity Algorithm
  double jaroWinkler(String s1, String s2) {
    if (s1 == s2) return 1.0;

    final len1 = s1.length;
    final len2 = s2.length;
    if (len1 == 0 || len2 == 0) return 0.0;

    final matchDistance = (math.max(len1, len2) ~/ 2) - 1;
    final maxMatchDist = matchDistance < 0 ? 0 : matchDistance;

    final s1Matches = List<bool>.filled(len1, false);
    final s2Matches = List<bool>.filled(len2, false);

    var matches = 0;
    for (var i = 0; i < len1; i++) {
      final start = math.max(0, i - maxMatchDist);
      final end = math.min(i + maxMatchDist + 1, len2);
      for (var j = start; j < end; j++) {
        if (s2Matches[j]) continue;
        if (s1[i] == s2[j]) {
          s1Matches[i] = true;
          s2Matches[j] = true;
          matches++;
          break;
        }
      }
    }

    if (matches == 0) return 0.0;

    var transpositions = 0;
    var k = 0;
    for (var i = 0; i < len1; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) {
        transpositions++;
      }
      k++;
    }

    final jaro = (matches / len1 + matches / len2 + (matches - transpositions / 2) / matches) / 3.0;

    // Winkler adjustment
    var prefix = 0;
    for (var i = 0; i < math.min(4, math.min(len1, len2)); i++) {
      if (s1[i] == s2[i]) {
        prefix++;
      } else {
        break;
      }
    }

    return jaro + prefix * 0.1 * (1.0 - jaro);
  }
}
