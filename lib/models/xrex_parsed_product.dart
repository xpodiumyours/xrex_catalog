import 'dart:ui';

class XRexParsedProduct {
  final String name;
  final String price;
  final String oldPrice;
  final String description;
  final String category;
  final Rect? sourceRect;
  final double? confidence;
  final List<String> sourceLines;
  final List<String> warnings;
  final String origin;
  final double? priceAmount;
  final String? sourceIndex;
  final int quantity;
  final List<String> detectionIds;

  const XRexParsedProduct({
    required this.name,
    required this.price,
    required this.description,
    this.oldPrice = '',
    this.category = 'Genel',
    this.sourceRect,
    this.confidence,
    this.sourceLines = const [],
    this.warnings = const [],
    this.origin = 'ocr',
    this.priceAmount,
    this.sourceIndex,
    this.quantity = 1,
    this.detectionIds = const [],
  });

  XRexParsedProduct copyWith({
    String? name,
    String? price,
    String? oldPrice,
    String? description,
    String? category,
    Rect? sourceRect,
    double? confidence,
    List<String>? sourceLines,
    List<String>? warnings,
    String? origin,
    double? priceAmount,
    String? sourceIndex,
    int? quantity,
    List<String>? detectionIds,
  }) {
    return XRexParsedProduct(
      name: name ?? this.name,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      description: description ?? this.description,
      category: category ?? this.category,
      sourceRect: sourceRect ?? this.sourceRect,
      confidence: confidence ?? this.confidence,
      sourceLines: sourceLines ?? this.sourceLines,
      warnings: warnings ?? this.warnings,
      origin: origin ?? this.origin,
      priceAmount: priceAmount ?? this.priceAmount,
      sourceIndex: sourceIndex ?? this.sourceIndex,
      quantity: quantity ?? this.quantity,
      detectionIds: detectionIds ?? this.detectionIds,
    );
  }
}
