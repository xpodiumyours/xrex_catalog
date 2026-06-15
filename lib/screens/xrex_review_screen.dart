import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/xrex_catalog_session.dart';
import '../services/xrex_catalog_service.dart';
import '../widgets/catalog_preview_list.dart';
import '../widgets/xrex_glass_panel.dart';
import '../widgets/xrex_step_indicator.dart';

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

    // Güvenli uyarı hesaplama (eksik isim veya fiyat olan ürün sayısı)
    final warningCount =
        validProducts
            .where((p) => p.name.trim().isEmpty || p.price.trim().isEmpty)
            .length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF080D18),
          surfaceTintColor: Colors.transparent,
          title: const Text('X-rex Son Kontrol'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.view_list_rounded), text: 'Önizleme'),
              Tab(icon: Icon(Icons.data_object_rounded), text: 'Teknik çıktı'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.35,
              colors: [Color(0xFF10213A), Color(0xFF050711)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const XRexStepIndicator(activeStep: 3),
                Expanded(
                  child: TabBarView(
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
                              warningCount: warningCount,
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: XRexGlassPanel(
                                padding: const EdgeInsets.all(0),
                                strongGlow: true,
                                child: Column(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: XRexSectionHeader(
                                        icon: Icons.data_object_rounded,
                                        eyebrow: 'TEKNİK ÇIKTI',
                                        title: 'Katalog JSON verisi',
                                        trailing: 'v1',
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.fromLTRB(
                                          14,
                                          0,
                                          14,
                                          14,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xE6050A14),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: const Color(0x3322D3EE),
                                          ),
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
                                  ],
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  final String businessType;
  final int productCount;
  final int warningCount;

  const _ReviewSummary({
    required this.businessType,
    required this.productCount,
    required this.warningCount,
  });

  @override
  Widget build(BuildContext context) {
    return XRexGlassPanel(
      strongGlow: true,
      child: Row(
        children: [
          const Icon(Icons.hub_rounded, color: Color(0xFF22D3EE)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SON KONTROL',
                  style: TextStyle(
                    color: Color(0xFF67E8F9),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$productCount ürün katalog taslağı hazır · $warningCount uyarı · $businessType',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
