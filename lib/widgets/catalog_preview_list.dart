import 'package:flutter/material.dart';

import '../models/xrex_draft_product.dart';
import 'xrex_glass_panel.dart';

class CatalogPreviewList extends StatelessWidget {
  final List<XRexDraftProduct> products;
  final String businessType;

  const CatalogPreviewList({
    super.key,
    required this.products,
    required this.businessType,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'Kataloga aktarılacak ürün yok.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: ListView.separated(
          padding: const EdgeInsets.all(18),
          itemCount: products.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _PreviewSummary(
                businessType: businessType,
                productCount: products.length,
              );
            }

            final product = products[index - 1];
            return XRexGlassPanel(
              accentColor: const Color(0xFF22C55E),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF052E2B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x6634D399)),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF34D399),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name.trim().isEmpty
                              ? 'İsimsiz ürün'
                              : product.name.trim(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          product.description.trim().isEmpty
                              ? product.category
                              : product.description.trim(),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ChipLabel(label: product.category),
                            _ChipLabel(label: product.stockStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    product.price.trim().isEmpty ? '-' : product.price.trim(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PreviewSummary extends StatelessWidget {
  final String businessType;
  final int productCount;

  const _PreviewSummary({
    required this.businessType,
    required this.productCount,
  });

  @override
  Widget build(BuildContext context) {
    return XRexGlassPanel(
      strongGlow: true,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF062D3B),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0x6606B6D4)),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Color(0xFF06B6D4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CATALOG PREVIEW',
                  style: TextStyle(
                    color: Color(0xFF67E8F9),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$productCount ürün katalog taslağı hazır',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'İşletme türü: $businessType',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _ChipLabel extends StatelessWidget {
  final String label;

  const _ChipLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x3322D3EE)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
