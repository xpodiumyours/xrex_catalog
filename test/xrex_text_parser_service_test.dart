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

  test('does not create products without price', () {
    final products = service.parseProducts('Sadece ürün adı var');

    expect(products, isEmpty);
  });
}
