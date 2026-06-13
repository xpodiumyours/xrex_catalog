import 'package:flutter/material.dart';

import '../models/xrex_draft_product.dart';

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF233149)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ürün #$index',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
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
}
