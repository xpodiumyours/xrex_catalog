import 'package:flutter/material.dart';
import '../models/xrex_draft_product.dart';

class XRexProductTable extends StatelessWidget {
  static const List<String> categoryOptions = [
    'Genel', 'Giyim', 'Gözlük', 'Aksesuar', 'Aktar ürünleri', 'Hırdavat',
    'Kozmetik', 'Kırtasiye', 'Oyuncak', 'Manav', 'Ev tekstili', 'Züccaciye', 'Diğer',
  ];

  final List<XRexDraftProduct> products;
  final bool isTableView;
  final Map<String, TextEditingController> nameControllers;
  final Map<String, TextEditingController> priceControllers;
  final Map<String, TextEditingController> descriptionControllers;
  final ValueChanged<XRexDraftProduct> onChanged;
  final Function(XRexDraftProduct) onDuplicate;
  final Function(XRexDraftProduct) onRemove;
  final List<String> Function(XRexDraftProduct) getWarnings;

  const XRexProductTable({
    super.key,
    required this.products,
    required this.isTableView,
    required this.nameControllers,
    required this.priceControllers,
    required this.descriptionControllers,
    required this.onChanged,
    required this.onDuplicate,
    required this.onRemove,
    required this.getWarnings,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Text('Henüz ürün bulunmuyor.', style: TextStyle(color: Colors.white24)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: products.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        final product = products[index];
        final warnings = getWarnings(product);
        final isWarning = warnings.isNotEmpty;
        final color = isWarning ? const Color(0xFFFF8A00) : const Color(0xFF22C55E);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // İkon ve Durum
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(product.category),
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              // İsim ve Alt Bilgi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameControllers[product.id],
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onChanged: (v) { product.name = v; onChanged(product); },
                    ),
                    Text(
                      "${product.category} • ${product.quantity} Adet",
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Fiyat Alanı (Özel Tasarım)
              Container(
                width: 85,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isWarning ? color.withValues(alpha: 0.3) : Colors.transparent),
                ),
                child: TextFormField(
                  controller: priceControllers[product.id],
                  textAlign: TextAlign.right,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    suffixText: " ₺",
                    suffixStyle: TextStyle(fontSize: 10),
                  ),
                  onChanged: (v) { product.price = v; onChanged(product); },
                ),
              ),
              // Silme butonu (Kaydırarak silme yerine hızlı buton)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white10),
                onPressed: () => onRemove(product),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Gözlük': return Icons.remove_red_eye_outlined;
      case 'Giyim': return Icons.checkroom_outlined;
      case 'Aktar ürünleri': return Icons.eco_outlined;
      case 'Hırdavat': return Icons.build_outlined;
      case 'Kozmetik': return Icons.face_outlined;
      case 'Kırtasiye': return Icons.edit_note_outlined;
      default: return Icons.inventory_2_outlined;
    }
  }
}
