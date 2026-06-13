import 'dart:convert';

import '../models/xrex_catalog_session.dart';
import '../models/xrex_draft_product.dart';

class XRexCatalogService {
  const XRexCatalogService();

  List<XRexDraftProduct> validProducts(List<XRexDraftProduct> products) {
    return products.where((product) => !product.isBlank).toList();
  }

  Map<String, dynamic> buildPayload(XRexCatalogSession session) {
    final products = validProducts(session.products);

    return {
      'source': 'xrex',
      'sessionId': session.sessionId,
      'businessType': session.businessType,
      'createdAt': DateTime.now().toIso8601String(),
      'products': products.map((product) => product.toJson()).toList(),
    };
  }

  String formattedJson(XRexCatalogSession session) {
    return const JsonEncoder.withIndent('  ').convert(buildPayload(session));
  }

  Map<String, dynamic> convertToVitrinXProductMap(XRexDraftProduct product) {
    return {
      'name': product.name.trim(),
      'price': product.price.trim(),
      'description': product.description.trim(),
      'category': product.category.trim(),
      'stockStatus': product.stockStatus.trim(),
      'imagePath': null,
    };
  }
}
