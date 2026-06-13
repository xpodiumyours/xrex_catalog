class XRexDraftProduct {
  final String id;
  String name;
  String price;
  String description;
  String category;
  String stockStatus;

  XRexDraftProduct({
    required this.id,
    this.name = '',
    this.price = '',
    this.description = '',
    this.category = 'Genel',
    this.stockStatus = 'Mevcut',
  });

  bool get isBlank => name.trim().isEmpty && price.trim().isEmpty;

  XRexDraftProduct copyWith({
    String? id,
    String? name,
    String? price,
    String? description,
    String? category,
    String? stockStatus,
  }) {
    return XRexDraftProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      category: category ?? this.category,
      stockStatus: stockStatus ?? this.stockStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name.trim(),
      'price': price.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'stockStatus': stockStatus.trim(),
    };
  }
}
