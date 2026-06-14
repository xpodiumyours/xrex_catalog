import 'dart:typed_data';

import 'xrex_draft_product.dart';

class XRexCatalogSession {
  final String sessionId;
  final String businessType;
  final Uint8List? selectedImageBytes;
  final String? selectedImagePath;
  final String ocrRawText;
  final List<XRexDraftProduct> products;

  const XRexCatalogSession({
    required this.sessionId,
    required this.businessType,
    required this.selectedImageBytes,
    this.selectedImagePath,
    this.ocrRawText = '',
    required this.products,
  });

  XRexCatalogSession copyWith({
    String? sessionId,
    String? businessType,
    Uint8List? selectedImageBytes,
    String? selectedImagePath,
    String? ocrRawText,
    List<XRexDraftProduct>? products,
  }) {
    return XRexCatalogSession(
      sessionId: sessionId ?? this.sessionId,
      businessType: businessType ?? this.businessType,
      selectedImageBytes: selectedImageBytes ?? this.selectedImageBytes,
      selectedImagePath: selectedImagePath ?? this.selectedImagePath,
      ocrRawText: ocrRawText ?? this.ocrRawText,
      products: products ?? this.products,
    );
  }
}
