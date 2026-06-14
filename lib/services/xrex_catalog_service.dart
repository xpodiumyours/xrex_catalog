import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/xrex_catalog_session.dart';
import '../models/xrex_draft_product.dart';

class XRexCatalogService {
  const XRexCatalogService();

  List<XRexDraftProduct> validProducts(List<XRexDraftProduct> products) {
    return products.where((product) => !product.isBlank).toList();
  }

  Map<String, dynamic> buildPayload(XRexCatalogSession session) {
    final products = validProducts(session.products);
    final emptyProductsRemoved = session.products.length - products.length;
    final sourcePhoto = _buildSourcePhoto(session);
    final productMaps =
        products.map((product) => _buildProduct(product)).toList();
    final warnings = <String>[
      if (emptyProductsRemoved > 0)
        '$emptyProductsRemoved boş ürün JSON çıktısına alınmadı.',
      for (final productMap in productMaps)
        ...((productMap['review'] as Map<String, dynamic>)['warnings']
                as List<String>)
            .map((warning) => '${productMap['id']}: $warning'),
    ];

    return {
      'schemaVersion': 'xrex.catalog.v1',
      'source': 'xrex',
      'exportType': 'catalog_draft',
      'session': {
        'id': session.sessionId,
        'createdAt': DateTime.now().toIso8601String(),
        'businessType': session.businessType,
        'platform': kIsWeb ? 'web' : 'mobile',
      },
      'sourcePhoto': sourcePhoto,
      'ocr': {
        'enabled': session.ocrRawText.trim().isNotEmpty,
        'engine':
            session.selectedImagePath == null
                ? null
                : 'google_mlkit_text_recognition',
        'rawText': session.ocrRawText.trim(),
        'candidates': const [],
      },
      'products': productMaps,
      'quality': {
        'productCount': productMaps.length,
        'emptyProductsRemoved': emptyProductsRemoved,
        'needsReview': true,
        'warnings': warnings,
      },
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

  Map<String, dynamic> _buildSourcePhoto(XRexCatalogSession session) {
    final pathAvailable =
        session.selectedImagePath != null &&
        session.selectedImagePath!.trim().isNotEmpty;
    return {
      'hasPhoto': session.selectedImageBytes != null,
      'storageType': 'local_memory',
      'pathAvailable': pathAvailable,
      'ocrSupported': pathAvailable && !kIsWeb,
      'note':
          pathAvailable
              ? 'Mobil ortamda dosya yolu OCR için kullanılabilir.'
              : 'Web ortamında dosya yolu yoktur; fotoğraf önizleme bytes ile gösterildi.',
    };
  }

  Map<String, dynamic> _buildProduct(XRexDraftProduct product) {
    final rawPrice = product.price.trim();
    final parsedAmount = _parsePriceAmount(rawPrice);
    final warnings = <String>[
      if (rawPrice.isNotEmpty && parsedAmount == null)
        'Fiyat sayısal değere çevrilemedi.',
      if (product.name.trim().isEmpty) 'Ürün adı boş.',
    ];

    return {
      'id': product.id,
      'status': 'draft',
      'name': {
        'raw': product.name.trim(),
        'normalized': _normalize(product.name),
      },
      'price': {
        'raw': rawPrice,
        'amount': parsedAmount,
        'currency': 'TRY',
        'isParsed': parsedAmount != null,
      },
      'description': {
        'raw': product.description.trim(),
        'normalized': _normalize(product.description),
      },
      'category': {
        'raw': product.category.trim(),
        'normalized': _normalize(product.category),
      },
      'stock': {
        'status': product.stockStatus.trim(),
        'isAvailable': _isAvailableStock(product.stockStatus),
      },
      'image': {
        'mode': 'source_photo_reference',
        'sourcePhotoId': 'session_photo',
        'crop': null,
      },
      'origin': {
        'createdBy': 'user_or_ocr',
        'confidence': null,
        'sourceLines': const [],
      },
      'review': {'needsUserReview': true, 'warnings': warnings},
    };
  }

  num? _parsePriceAmount(String rawPrice) {
    final match = RegExp(r'\d{1,9}(?:[.,]\d{1,2})?').firstMatch(rawPrice);
    if (match == null) return null;

    final normalized = match.group(0)!.replaceAll(',', '.');
    final parsed = num.tryParse(normalized);
    if (parsed == null) return null;
    if (parsed % 1 == 0) return parsed.toInt();
    return parsed;
  }

  String _normalize(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _isAvailableStock(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'mevcut' ||
        normalized == 'stokta var' ||
        normalized == 'var';
  }
}
