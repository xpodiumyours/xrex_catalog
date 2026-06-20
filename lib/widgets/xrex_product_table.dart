import 'package:flutter/material.dart';
import '../models/xrex_draft_product.dart';
import 'xrex_glass_panel.dart';

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
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Henüz eklenmiş ürün taslağı bulunmuyor.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ),
      );
    }

    if (isTableView) {
      return _buildTableView(context);
    } else {
      return _buildCardView(context);
    }
  }

  Widget _buildTableView(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Theme(
          data: Theme.of(
            context,
          ).copyWith(dividerColor: const Color(0xFF1F2A3D)),
          child: DataTable(
            columnSpacing: 18,
            horizontalMargin: 8,
            columns: const [
              DataColumn(
                label: Text(
                  '#',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Ürün Adı',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Fiyat',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Adet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Kategori',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'Durum',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              DataColumn(
                label: Text(
                  'İşlem',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
            rows: List.generate(products.length, (index) {
              final product = products[index];
              final warnings = getWarnings(product);
              final isWarning = warnings.isNotEmpty;

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      product.sourceIndex ?? '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Ürün Adı Girişi
                  DataCell(
                    SizedBox(
                      width: 170,
                      child: TextFormField(
                        controller: nameControllers[product.id],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          border: InputBorder.none,
                          hintText: 'Ürün adı girin',
                        ),
                        onChanged: (val) {
                          product.name = val;
                          onChanged(product);
                        },
                      ),
                    ),
                  ),
                  // Fiyat Girişi
                  DataCell(
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: priceControllers[product.id],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          border: InputBorder.none,
                          hintText: '0.00 TL',
                        ),
                        onChanged: (val) {
                          product.price = val;
                          onChanged(product);
                        },
                      ),
                    ),
                  ),
                  // Adet Girişi
                  DataCell(
                    SizedBox(
                      width: 50,
                      child: TextFormField(
                        initialValue: product.quantity.toString(),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          border: InputBorder.none,
                          hintText: '1',
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            product.quantity = parsed;
                            onChanged(product);
                          }
                        },
                      ),
                    ),
                  ),
                  // Kategori
                  DataCell(
                    DropdownButton<String>(
                      value:
                          categoryOptions.contains(product.category)
                              ? product.category
                              : 'Genel',
                      dropdownColor: const Color(0xFF090D18),
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      items:
                          categoryOptions
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          product.category = val;
                          onChanged(product);
                        }
                      },
                    ),
                  ),
                  // Durum (✅ / ⚠️)
                  DataCell(
                    Icon(
                      isWarning
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_rounded,
                      color:
                          isWarning
                              ? const Color(0xFFFF8A00)
                              : const Color(0xFF22C55E),
                      size: 18,
                    ),
                  ),
                  // Kopyala / Sil
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => onDuplicate(product),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => onRemove(product),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCardView(BuildContext context) {
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final product = products[index];
        final warnings = getWarnings(product);
        final isWarning = warnings.isNotEmpty;
        final statusColor =
            isWarning ? const Color(0xFFFF8A00) : const Color(0xFF22C55E);

        return XRexGlassPanel(
          accentColor: statusColor,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isWarning
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    color: statusColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    product.sourceIndex != null
                        ? 'Ürün ${product.sourceIndex} · ${product.quantity} Adet'
                        : 'Ürün #${index + 1} · ${product.quantity} Adet',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    onPressed: () => onDuplicate(product),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => onRemove(product),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameControllers[product.id],
                decoration: const InputDecoration(
                  labelText: 'Ürün Adı',
                  isDense: true,
                ),
                onChanged: (val) {
                  product.name = val;
                  onChanged(product);
                },
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final useColumn = constraints.maxWidth < 340;

                  if (useColumn) {
                    return Column(
                      children: [
                        TextFormField(
                          controller: priceControllers[product.id],
                          decoration: const InputDecoration(labelText: 'Fiyat', isDense: true),
                          onChanged: (val) {
                            product.price = val;
                            onChanged(product);
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: categoryOptions.contains(product.category) ? product.category : 'Genel',
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Kategori', isDense: true),
                          dropdownColor: const Color(0xFF090D18),
                          items: categoryOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) { if (val != null) { product.category = val; onChanged(product); } },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: product.quantity.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Adet', isDense: true),
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed > 0) {
                              product.quantity = parsed;
                              onChanged(product);
                            }
                          },
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: priceControllers[product.id],
                          decoration: const InputDecoration(
                            labelText: 'Fiyat',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          ),
                          onChanged: (val) {
                            product.price = val;
                            onChanged(product);
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          value:
                              categoryOptions.contains(product.category)
                                  ? product.category
                                  : 'Genel',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                          ),
                          dropdownColor: const Color(0xFF090D18),
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          items:
                              categoryOptions
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(
                                        category,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              product.category = val;
                              onChanged(product);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: product.quantity.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Adet',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed > 0) {
                              product.quantity = parsed;
                              onChanged(product);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descriptionControllers[product.id],
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Açıklama / ürün bilgisi',
                  isDense: true,
                ),
                onChanged: (val) {
                  product.description = val;
                  onChanged(product);
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (product.detectionId != null) ...[
                    _StatusPill(
                      label: '${product.detectionId} algılandı',
                      color: const Color(0xFF22D3EE),
                    ),
                  ],
                  _StatusPill(
                    label: product.stockStatus,
                    color: const Color(0xFF22D3EE),
                  ),
                  _StatusPill(
                    label: isWarning ? 'Kontrol gerekli' : 'Hazır',
                    color:
                        isWarning
                            ? const Color(0xFFFF8A00)
                            : const Color(0xFF22C55E),
                  ),
                  if (product.confidence != null) ...[
                    _StatusPill(
                      label: '%${(product.confidence! * 100).round()} güven',
                      color: const Color(0xFF818CF8),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
