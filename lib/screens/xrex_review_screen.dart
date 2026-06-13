import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/xrex_catalog_session.dart';
import '../services/xrex_catalog_service.dart';
import '../widgets/catalog_preview_list.dart';

class XRexReviewScreen extends StatelessWidget {
  final XRexCatalogSession session;

  const XRexReviewScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    const service = XRexCatalogService();
    final validProducts = service.validProducts(session.products);
    final formattedJson = service.formattedJson(
      session.copyWith(products: validProducts),
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('X-rex Son Kontrol'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.view_list_rounded), text: 'Önizleme'),
              Tab(icon: Icon(Icons.data_object_rounded), text: 'JSON'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CatalogPreviewList(
              products: validProducts,
              businessType: session.businessType,
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ReviewSummary(
                    businessType: session.businessType,
                    productCount: validProducts.length,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF050A14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF233149)),
                      ),
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              formattedJson,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: 1.45,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: formattedJson),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Katalog JSON verisi panoya kopyalandı.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('JSON kopyala'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: const Color(0xFF04111D),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  final String businessType;
  final int productCount;

  const _ReviewSummary({
    required this.businessType,
    required this.productCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF233149)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF22C55E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$productCount ürün hazırlandı · İşletme türü: $businessType',
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
