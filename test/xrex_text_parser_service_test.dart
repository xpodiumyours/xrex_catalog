import 'package:flutter_test/flutter_test.dart';
import 'package:xrex_catalog/services/xrex_text_parser_service.dart';

void main() {
  const service = XRexTextParserService();

  test('parses product and price on the same line', () {
    final products = service.parseProducts('Penti çorap 175 TL');

    expect(products, hasLength(1));
    expect(products.first.name, 'Penti çorap');
    expect(products.first.price, '175 TL');
  });

  test('matches price on next line with previous product name', () {
    final products = service.parseProducts('Penti çorap\n175 TL');

    expect(products, hasLength(1));
    expect(products.first.name, 'Penti çorap');
    expect(products.first.price, '175 TL');
  });

  test('combines brand and product lines before price', () {
    final products = service.parseProducts('PENTI\nKadın Çorap\n175 TL');

    expect(products, hasLength(1));
    expect(products.first.name, 'PENTI Kadın Çorap');
    expect(products.first.price, '175 TL');
  });

  test('parses multiple products', () {
    final products = service.parseProducts(
      'Kadın Çorap\n175 TL\nKadın Pijama Takımı\n350 TL',
    );

    expect(products, hasLength(2));
    expect(products[0].name, 'Kadın Çorap');
    expect(products[0].price, '175 TL');
    expect(products[1].name, 'Kadın Pijama Takımı');
    expect(products[1].price, '350 TL');
  });

  test('uses first following text line as description', () {
    final products = service.parseProducts('Kadın Çorap\n175 TL\nParlak model');

    expect(products, hasLength(1));
    expect(products.first.description, 'Parlak model');
  });

  test('ignores empty and noisy lines', () {
    final products = service.parseProducts('PENTI\n\nKadın Çorap\n\n175 TL');

    expect(products, hasLength(1));
    expect(products.first.name, 'PENTI Kadın Çorap');
    expect(products.first.price, '175 TL');
  });

  test('creates products without price as fallback', () {
    final products = service.parseProducts('Sadece ürün adı var');

    expect(products, hasLength(1));
    expect(products.first.name, 'Sadece ürün adı var');
    expect(products.first.price, '');
  });

  test('parses Turkish thousands with comma decimal format', () {
    final products = service.parseProducts('Ofis koltuğu\n1.250,00 TL');

    expect(products, hasLength(1));
    expect(products.first.price, '1.250,00 TL');
  });

  test('parses spaced thousands format', () {
    final products = service.parseProducts('Ofis koltuğu\n1 250,00 TL');

    expect(products, hasLength(1));
    expect(products.first.price, '1 250,00 TL');
  });

  test('ignores discount context lines as price', () {
    final products = service.parseProducts(
      'Kadın Çorap\nSepette %20 indirim\n175 TL',
    );

    expect(products, hasLength(1));
    expect(products.first.name, 'Kadın Çorap');
    expect(products.first.price, '175 TL');
  });

  test('ignores coupon amount lines as price', () {
    final products = service.parseProducts(
      'Kadın Çorap\n100 TL Kupon\n175 TL',
    );

    expect(products, hasLength(1));
    expect(products.first.price, '175 TL');
  });

  test('chooses meaningful title lines instead of ui noise', () {
    final products = service.parseProducts(
      'Ana Sayfa\nMağazada ara\nQBC\nOfis büro çalışma koltuğu\n175 TL',
    );

    expect(products, hasLength(1));
    expect(products.first.name, 'QBC Ofis büro çalışma koltuğu');
    expect(products.first.sourceLines, ['QBC', 'Ofis büro çalışma koltuğu']);
  });

  test('filters page numbers and currency-only lines from name buffer', () {
    final products = service.parseProducts(
      '1\nTL\nPENTI\nKadın Çorap\n175 TL',
    );

    expect(products, hasLength(1));
    expect(products.first.name, 'PENTI Kadın Çorap');
  });

  test('adds warning when product name spans too many lines', () {
    final products = service.parseProducts(
      'QBC\nUltra ergonomik nefes alan fileli ofis çalışma koltuğu\n'
      'Sırt destekli modern tasarım ev ofis kullanımı\n7.250 TL',
    );

    expect(products, hasLength(1));
    expect(
      products.first.name,
      'QBC Ultra ergonomik nefes alan fileli ofis çalışma koltuğu '
      'Sırt destekli modern tasarım ev ofis kullanımı',
    );
    expect(
      products.first.warnings,
      contains('Ürün adı uzun, kontrol önerilir.'),
    );
  });
}
