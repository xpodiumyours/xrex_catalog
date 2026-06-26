import 'package:flutter_test/flutter_test.dart';
import 'package:xrex_catalog/services/xrex_portfolio_service.dart';

void main() {
  group('XRexPortfolioService Tests', () {
    late XRexPortfolioService service;

    setUp(() {
      service = XRexPortfolioService();
      service.products.clear();
    });

    test('should correctly parse Google Sheets URLs into TSV export URLs', () {
      const editUrl = 'https://docs.google.com/spreadsheets/d/1FDg2nTK_C1r346QhhoRYQMLRetnEHTLRFz2yVxiUXE/edit#gid=1984083474';
      final exportUrl = service.convertToExportUrl(editUrl);
      expect(exportUrl, 'https://docs.google.com/spreadsheets/d/1FDg2nTK_C1r346QhhoRYQMLRetnEHTLRFz2yVxiUXE/export?format=tsv&gid=1984083474');

      const simpleUrl = 'https://docs.google.com/spreadsheets/d/1FDg2nTK_C1r346QhhoRYQMLRetnEHTLRFz2yVxiUXE/edit';
      final simpleExportUrl = service.convertToExportUrl(simpleUrl);
      expect(simpleExportUrl, 'https://docs.google.com/spreadsheets/d/1FDg2nTK_C1r346QhhoRYQMLRetnEHTLRFz2yVxiUXE/export?format=tsv');
    });

    test('should correctly parse TSV content', () {
      const mockTsv = 'urun_adi\tkategori\taciklama\tocr_eslesme_kelimeleri\n'
          'Nescafe Xpress Black Roast\t\u0130\u00e7ecekler\tTaze so\u011fuk kahve\tnescafe xpress, black roast\n'
          'Starbucks Frappuccino\t\u0130\u00e7ecekler\t\u015e\u0130\u015fede kahve keyfi\tstarbucks, frappuccino\n';

      final success = service.parseTsv(mockTsv);
      expect(success, isTrue);
      expect(service.products.length, 2);

      final p1 = service.products.first;
      expect(p1.name, 'Nescafe Xpress Black Roast');
      expect(p1.category, '\u0130\u00e7ecekler');
      expect(p1.description, 'Taze so\u011fuk kahve');
      expect(p1.aliases, ['nescafe xpress', 'black roast']);
    });

    test('should calculate Jaro-Winkler similarity accurately', () {
      expect(service.jaroWinkler('test', 'test'), 1.0);
      expect(service.jaroWinkler('cizi', 'cizi'), 1.0);
      expect(service.jaroWinkler('cizi', 'çizi') > 0.8, isTrue);
      expect(service.jaroWinkler('abc', 'xyz'), 0.0);
    });

    test('should find best portfolio matches for noisy OCR strings', () {
      // Re-load defaults to test matching
      service.parseTsv('urun_adi\tkategori\taciklama\tocr_eslesme_kelimeleri\n'
          'Nescafe Xpress Black Roast So\u011fuk Kahve\t\u0130\u00e7ecekler\tTaze kahve\tnescafe xpress, black roast, xpress black\n'
          '\u00dclker \u00c7izi Kraker\tAt\u0131\u015ft\u0131rmal\u{0131}k\tTuzlu kraker\tcizi, \u00e7izi, ulker cizi\n');

      final match1 = service.findBestMatch('Nescafe Xprs Blck');
      expect(match1, isNotNull);
      expect(match1!.product.name, 'Nescafe Xpress Black Roast So\u011fuk Kahve');
      expect(match1.confidence > 0.8, isTrue);

      final match2 = service.findBestMatch('ulker c1z1');
      expect(match2, isNotNull);
      expect(match2!.product.name, '\u00dclker \u00c7izi Kraker');
      expect(match2.product.category, 'At\u0131\u015ft\u0131rmal\u{0131}k');
    });
  });
}
