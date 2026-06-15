class XRexDraftProduct {
  final String id;
  String name;
  String price;
  String description;
  String category;
  String stockStatus;
  String oldPrice;
  String? sourceLineSummary;
  List<String> parserWarnings;
  String? detectionId;
  String origin;
  double? confidence;
  double? priceAmount;
  List<String> sourceLines;
  String? sourceIndex;
  int quantity;
  List<String> detectionIds;

  XRexDraftProduct({
    required this.id,
    this.name = '',
    this.price = '',
    this.description = '',
    this.category = 'Genel',
    this.stockStatus = 'Mevcut',
    this.oldPrice = '',
    this.sourceLineSummary,
    this.parserWarnings = const [],
    this.detectionId,
    this.origin = 'manual',
    this.confidence,
    this.priceAmount,
    this.sourceLines = const [],
    this.sourceIndex,
    this.quantity = 1,
    this.detectionIds = const [],
  });

  bool get isBlank => name.trim().isEmpty && price.trim().isEmpty;

  XRexDraftProduct copyWith({
    String? id,
    String? name,
    String? price,
    String? description,
    String? category,
    String? stockStatus,
    String? oldPrice,
    String? sourceLineSummary,
    List<String>? parserWarnings,
    String? detectionId,
    String? origin,
    double? confidence,
    double? priceAmount,
    List<String>? sourceLines,
    String? sourceIndex,
    int? quantity,
    List<String>? detectionIds,
  }) {
    return XRexDraftProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      category: category ?? this.category,
      stockStatus: stockStatus ?? this.stockStatus,
      oldPrice: oldPrice ?? this.oldPrice,
      sourceLineSummary: sourceLineSummary ?? this.sourceLineSummary,
      parserWarnings: parserWarnings ?? this.parserWarnings,
      detectionId: detectionId ?? this.detectionId,
      origin: origin ?? this.origin,
      confidence: confidence ?? this.confidence,
      priceAmount: priceAmount ?? this.priceAmount,
      sourceLines: sourceLines ?? this.sourceLines,
      sourceIndex: sourceIndex ?? this.sourceIndex,
      quantity: quantity ?? this.quantity,
      detectionIds: detectionIds ?? this.detectionIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description.trim(),
      'stockStatus': stockStatus.trim(),
      'detectionId': detectionId,
      'sourceIndex': sourceIndex,
      'quantity': quantity,
      'detectionIds': detectionIds,
      'name': {
        'raw': name.trim(),
      },
      'price': {
        'raw': price.trim(),
        'amount': priceAmount,
        'oldRaw': oldPrice.trim(),
      },
      'category': {
        'normalized': category.trim(),
      },
      'origin': {
        'sourceLines': sourceLines,
        'confidence': confidence,
        'type': origin,
      },
      'review': {
        'warnings': parserWarnings,
      },
    };
  }
}
