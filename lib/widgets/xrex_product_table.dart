import 'package:flutter/material.dart';
import '../models/xrex_draft_product.dart';

class XRexProductTable extends StatelessWidget {
  static const List<String> categoryOptions = [
    'Genel',
    'Giyim',
    'Gözlük',
    'Aksesuar',
    'Aktar ürünleri',
    'Hırdavat',
    'Kozmetik',
    'Kırtasiye',
    'Oyuncak',
    'Manav',
    'Ev tekstili',
    'Züccaciye',
    'Diğer',
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
        child: Text(
          'Henüz ürün bulunmuyor.',
          style: TextStyle(color: Colors.white24),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final product = products[index];
        final warnings = getWarnings(product);
        final isWarning = warnings.isNotEmpty;
        final color =
            isWarning ? const Color(0xFFFF8A00) : const Color(0xFF22C55E);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xE60B1220),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  isWarning
                      ? color.withValues(alpha: 0.45)
                      : const Color(0x3322D3EE),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF020617).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.rawOcrText != null && product.rawOcrText!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
                  child: Text(
                    'Ham OCR: ${product.rawOcrText}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              Row(
                children: [
                  Checkbox(
                    value: product.isApproved,
                    onChanged: (val) {
                      product.isApproved = val ?? false;
                      onChanged(product);
                    },
                    activeColor: const Color(0xFF22C55E),
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                  ),
                  // İkon ve Durum
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.28)),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                          onChanged: (v) {
                            product.name = v;
                            onChanged(product);
                          },
                        ),
                        Text(
                          "${product.category} • ${product.quantity} Adet",
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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
                      color: const Color(0xFF071428),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isWarning
                                ? color.withValues(alpha: 0.3)
                                : const Color(0x2219D3EE),
                      ),
                    ),
                    child: TextFormField(
                      controller: priceControllers[product.id],
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        suffixText: " ₺",
                        suffixStyle: TextStyle(fontSize: 10),
                      ),
                      onChanged: (v) {
                        product.price = v;
                        onChanged(product);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kopyala',
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 17,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () => onDuplicate(product),
                  ),
                  IconButton(
                    tooltip: 'Sil',
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () => onRemove(product),
                  ),
                ],
              ),
              if (product.suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: product.suggestions.map((sug) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ActionChip(
                          backgroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFF334155)),
                          label: Text(sug.name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          onPressed: () {
                            product.name = sug.name;
                            product.category = sug.category;
                            product.description = sug.description;
                            if (sug.price.isNotEmpty) {
                              product.price = sug.price;
                              final parsedAmount = double.tryParse(sug.price.replaceAll(',', '.'));
                              if (parsedAmount != null) product.priceAmount = parsedAmount;
                            }
                            nameControllers[product.id]?.text = sug.name;
                            descriptionControllers[product.id]?.text = sug.description;
                            priceControllers[product.id]?.text = product.price;
                            product.origin = 'portfolio_matched_strong'; // Promote
                            onChanged(product);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Gözlük':
        return Icons.remove_red_eye_outlined;
      case 'Giyim':
        return Icons.checkroom_outlined;
      case 'Aktar ürünleri':
        return Icons.eco_outlined;
      case 'Hırdavat':
        return Icons.build_outlined;
      case 'Kozmetik':
        return Icons.face_outlined;
      case 'Kırtasiye':
        return Icons.edit_note_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}
