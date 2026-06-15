import 'package:flutter/material.dart';

import '../models/xrex_draft_product.dart';
import 'xrex_glass_panel.dart';

class XRexDraftProductCard extends StatelessWidget {
  final int index;
  final XRexDraftProduct product;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController descriptionController;
  final FocusNode nameFocusNode;
  final FocusNode priceFocusNode;
  final FocusNode descriptionFocusNode;
  final ValueChanged<XRexDraftProduct> onChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final List<String> warnings;

  const XRexDraftProductCard({
    super.key,
    required this.index,
    required this.product,
    required this.nameController,
    required this.priceController,
    required this.descriptionController,
    required this.nameFocusNode,
    required this.priceFocusNode,
    required this.descriptionFocusNode,
    required this.onChanged,
    required this.onDuplicate,
    required this.onRemove,
    this.warnings = const [],
  });

  static const List<String> categories = [
    'Genel',
    'Aktar ürünleri',
    'Giyim',
    'Nalbur',
    'Kozmetik',
    'Oyuncak',
    'Gıda',
    'Aksesuar',
    'Elektronik',
    'Ev ürünleri',
    'Diğer',
  ];

  static const List<String> stockStatuses = [
    'Mevcut',
    'Son birkaç adet',
    'Tükendi',
  ];

  @override
  Widget build(BuildContext context) {
    final status = _statusLabel();
    final statusColor =
        warnings.isEmpty ? const Color(0xFF22C55E) : const Color(0xFFF97316);
    return XRexGlassPanel(
      accentColor: statusColor,
      strongGlow: warnings.isEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Icon(
                  warnings.isEmpty
                      ? Icons.check_rounded
                      : Icons.priority_high_rounded,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.sourceIndex != null
                          ? 'Ürün ${product.sourceIndex} · ${product.quantity} Adet'
                          : 'Ürün #$index · ${product.quantity} Adet',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Kopyala',
                onPressed: onDuplicate,
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Sil',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  warnings
                      .map((warning) => _WarningChip(label: warning))
                      .toList(),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            focusNode: nameFocusNode,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Ürün adı'),
            onChanged: (value) {
              product.name = value;
              onChanged(product);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: priceController,
                  focusNode: priceFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Fiyat'),
                  onChanged: (value) {
                    product.price = value;
                    onChanged(product);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: DropdownButtonFormField<String>(
                  value:
                      categories.contains(product.category)
                          ? product.category
                          : 'Genel',
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items:
                      categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    product.category = value;
                    onChanged(product);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: product.quantity.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Adet'),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed > 0) {
                      product.quantity = parsed;
                      onChanged(product);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            focusNode: descriptionFocusNode,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Açıklama'),
            onChanged: (value) {
              product.description = value;
              onChanged(product);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value:
                stockStatuses.contains(product.stockStatus)
                    ? product.stockStatus
                    : 'Mevcut',
            decoration: const InputDecoration(labelText: 'Stok durumu'),
            items:
                stockStatuses
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
            onChanged: (value) {
              if (value == null) return;
              product.stockStatus = value;
              onChanged(product);
            },
          ),
        ],
      ),
    );
  }

  String _statusLabel() {
    if (warnings.isEmpty) return 'Hazır';
    if (warnings.any((warning) => warning.contains('eksik'))) {
      return 'Eksik bilgi';
    }
    return 'Kontrol gerekli';
  }
}

class _WarningChip extends StatelessWidget {
  final String label;

  const _WarningChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3B1D0A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF97316)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF97316),
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFED7AA),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
