class XRexPortfolioProduct {
  final String id;
  final String name;
  final String category;
  final String price;
  final String description;
  final List<String> aliases;

  const XRexPortfolioProduct({
    required this.id,
    required this.name,
    required this.category,
    this.price = '',
    this.description = '',
    this.aliases = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'description': description,
      'aliases': aliases,
    };
  }

  factory XRexPortfolioProduct.fromJson(Map<String, dynamic> json) {
    return XRexPortfolioProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      price: (json['price'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      aliases: List<String>.from(json['aliases'] ?? const []),
    );
  }
}
