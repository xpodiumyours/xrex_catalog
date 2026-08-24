import 'package:flutter_test/flutter_test.dart';
import 'package:xrex_catalog/models/xrex_catalog_session.dart';
import 'package:xrex_catalog/models/xrex_draft_product.dart';
import 'package:xrex_catalog/services/xrex_catalog_service.dart';

void main() {
  const service = XRexCatalogService();

  test('triggers visual_inventory mode and generates Kozmetik blog draft when no prices are valid', () {
    final session = XRexCatalogSession(
      sessionId: 'test-session',
      businessType: 'Kozmetikçi',
      selectedImageBytes: null,
      products: [
        XRexDraftProduct(
          id: 'prod-1',
          name: 'Yüz Nemlendirici Krem',
          price: '', // No price!
          category: 'Kozmetik',
        ),
      ],
    );

    final payload = service.buildPayload(session);

    expect(payload['exportType'], 'visual_inventory');
    expect(payload['mode'], 'visual_inventory');
    expect(payload.containsKey('blogDraft'), isTrue);

    final blog = payload['blogDraft'] as Map<String, dynamic>;
    expect(blog['title'], contains('Cilt Bakımı'));
    expect(blog['suggestedStoreCategory'], 'Kozmetik & Kişisel Bakım');
    expect(blog['keywords'], contains('cilt bakımı'));
  });

  test('triggers visual_inventory mode and generates Giyim blog draft when prices fail parsing', () {
    final session = XRexCatalogSession(
      sessionId: 'test-session',
      businessType: 'Butik',
      selectedImageBytes: null,
      products: [
        XRexDraftProduct(
          id: 'prod-1',
          name: 'Keten Elbise',
          price: 'Fiyat Yok', // Fails parsing to numeric price amount!
          category: 'Giyim',
        ),
      ],
    );

    final payload = service.buildPayload(session);

    expect(payload['exportType'], 'visual_inventory');
    expect(payload.containsKey('blogDraft'), isTrue);

    final blog = payload['blogDraft'] as Map<String, dynamic>;
    expect(blog['title'], contains('Giyim Trendleri'));
    expect(blog['suggestedStoreCategory'], 'Giyim & Aksesuar');
  });

  test('keeps catalog_draft mode when at least one product has a valid price', () {
    final session = XRexCatalogSession(
      sessionId: 'test-session',
      businessType: 'Butik',
      selectedImageBytes: null,
      products: [
        XRexDraftProduct(
          id: 'prod-1',
          name: 'Keten Elbise',
          price: 'Fiyat Yok',
          category: 'Giyim',
        ),
        XRexDraftProduct(
          id: 'prod-2',
          name: 'Pamuklu Tişört',
          price: '350 TL', // Valid price amount!
          category: 'Giyim',
          isApproved: true,
        ),
      ],
    );

    final payload = service.buildPayload(session);

    expect(payload['exportType'], 'catalog_draft');
    expect(payload.containsKey('blogDraft'), isFalse);
  });
}
