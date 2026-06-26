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
    final statusColor = _statusColor();
    return XRexGlassPanel(
      accentColor: statusColor,
      strongGlow: product.isApproved,
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
                  product.isApproved
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
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kataloğa Ekle (Onay)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              Switch(
                value: product.isApproved,
                onChanged: (val) {
                  product.isApproved = val;
                  onChanged(product);
                },
                activeTrackColor: const Color(0xFF22C55E).withValues(alpha: 0.5),
                activeThumbColor: const Color(0xFF22C55E),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (product.origin == 'portfolio_matched_strong')
                const _WarningChip(label: 'Güçlü Eşleşme', color: Color(0xFF22C55E), icon: Icons.verified),
              if (product.origin == 'portfolio_matched_weak')
                const _WarningChip(label: 'Zayıf Eşleşme', color: Color(0xFFEAB308), icon: Icons.help_outline),
              if (product.origin == 'unmatched')
                const _WarningChip(label: 'Eşleşme Yok', color: Color(0xFFEF4444), icon: Icons.error_outline),
              ...warnings.map((w) => _WarningChip(label: w, color: const Color(0xFFF97316), icon: Icons.warning_amber_rounded)),
            ],
          ),
          if (product.rawOcrText != null && product.rawOcrText!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.document_scanner_outlined, color: Colors.white54, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ham OCR: ${product.rawOcrText}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (product.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Önerilen Eşleşmeler:',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: product.suggestions.map((sug) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      backgroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Color(0xFF334155)),
                      label: Text(sug.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      onPressed: () {
                        product.name = sug.name;
                        product.category = sug.category;
                        product.description = sug.description;
                        if (sug.price.isNotEmpty) {
                          product.price = sug.price;
                          final parsedAmount = double.tryParse(sug.price.replaceAll(',', '.'));
                          if (parsedAmount != null) product.priceAmount = parsedAmount;
                        }
                        nameController.text = sug.name;
                        descriptionController.text = sug.description;
                        priceController.text = product.price;
                        product.origin = 'portfolio_matched_strong'; // Promoted to strong manually
                        onChanged(product);
                      },
                    ),
                  );
                }).toList(),
              ),
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
                  initialValue:
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
            initialValue:
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

  Color _statusColor() {
    if (!product.isApproved) return const Color(0xFFF97316); // Orange for pending
    if (warnings.isEmpty) return const Color(0xFF22C55E); // Green for ready
    return const Color(0xFFEAB308); // Yellow for warnings but approved
  }

  String _statusLabel() {
    if (!product.isApproved) return 'Onay Bekliyor';
    if (warnings.isEmpty) return 'Onaylandı';
    return 'Onaylandı (Uyarılı)';
  }
}

class _WarningChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _WarningChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
