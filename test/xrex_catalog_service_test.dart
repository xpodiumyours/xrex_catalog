import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrex_catalog/models/xrex_catalog_session.dart';
import 'package:xrex_catalog/models/xrex_draft_product.dart';
import 'package:xrex_catalog/services/xrex_catalog_service.dart';

void main() {
  const service = XRexCatalogService();

  XRexCatalogSession sessionWithProducts(List<XRexDraftProduct> products) {
    return XRexCatalogSession(
      sessionId: 'test-session',
      businessType: 'Butik',
      selectedImageBytes: Uint8List.fromList([1, 2, 3]),
      products: products,
    );
  }

  test('builds master JSON with parsed TRY price', () {
    final payload = service.buildPayload(
      sessionWithProducts([
        XRexDraftProduct(
          id: 'prod-1',
          name: 'Penti çorap',
          price: '175 TL',
          description: 'Parlak model',
          category: 'Giyim',
        ),
      ]),
    );

    final product = (payload['products'] as List).first as Map<String, dynamic>;
    final price = product['price'] as Map<String, dynamic>;

    expect(payload['schemaVersion'], 'xrex.catalog.v1');
    expect(payload['exportType'], 'catalog_draft');
    expect(price['raw'], '175 TL');
    expect(price['amount'], 175);
    expect(price['currency'], 'TRY');
    expect(price['isParsed'], true);
  });

  test('parses comma decimal price', () {
    final payload = service.buildPayload(
      sessionWithProducts([
        XRexDraftProduct(id: 'prod-1', name: 'Ürün', price: '175,50 TL'),
      ]),
    );

    final product = (payload['products'] as List).first as Map<String, dynamic>;
    final price = product['price'] as Map<String, dynamic>;

    expect(price['amount'], 175.5);
    expect(price['isParsed'], true);
  });

  test('keeps unparsed price and adds warning', () {
    final payload = service.buildPayload(
      sessionWithProducts([
        XRexDraftProduct(id: 'prod-1', name: 'Ürün', price: 'Pazarlık'),
      ]),
    );

    final product = (payload['products'] as List).first as Map<String, dynamic>;
    final price = product['price'] as Map<String, dynamic>;
    final review = product['review'] as Map<String, dynamic>;

    expect(price['amount'], null);
    expect(price['isParsed'], false);
    expect(review['warnings'], contains('Fiyat sayısal değere çevrilemedi.'));
  });

  test('describes web-like photo without path', () {
    final payload = service.buildPayload(
      sessionWithProducts([
        XRexDraftProduct(id: 'prod-1', name: 'Ürün', price: '10 TL'),
      ]),
    );

    final sourcePhoto = payload['sourcePhoto'] as Map<String, dynamic>;

    expect(sourcePhoto['hasPhoto'], true);
    expect(sourcePhoto['pathAvailable'], false);
    expect(sourcePhoto['ocrSupported'], false);
  });

  test('describes mobile photo with path as OCR supported', () {
    final payload = service.buildPayload(
      XRexCatalogSession(
        sessionId: 'test-session',
        businessType: 'Butik',
        selectedImageBytes: Uint8List.fromList([1, 2, 3]),
        selectedImagePath: '/tmp/photo.jpg',
        products: [
          XRexDraftProduct(id: 'prod-1', name: 'Ürün', price: '10 TL'),
        ],
      ),
    );

    final sourcePhoto = payload['sourcePhoto'] as Map<String, dynamic>;

    expect(sourcePhoto['pathAvailable'], true);
    expect(sourcePhoto['ocrSupported'], true);
  });

  test('removes blank products and reports quality count', () {
    final payload = service.buildPayload(
      sessionWithProducts([
        XRexDraftProduct(id: 'prod-1', name: 'Ürün', price: '10 TL'),
        XRexDraftProduct(id: 'blank'),
      ]),
    );

    final products = payload['products'] as List;
    final quality = payload['quality'] as Map<String, dynamic>;

    expect(products.length, 1);
    expect(quality['productCount'], 1);
    expect(quality['emptyProductsRemoved'], 1);
  });
}
