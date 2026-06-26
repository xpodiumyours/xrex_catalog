// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/xrex_catalog_session.dart';
import '../models/xrex_draft_product.dart';
import '../models/xrex_blog_draft.dart';
import 'xrex_price_parser.dart';

class XRexCatalogService {
  const XRexCatalogService();

  List<XRexDraftProduct> validProducts(List<XRexDraftProduct> products) {
    return products.where((product) => !product.isBlank && product.isApproved).toList();
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

    // Detect if we have any ready product with both name and amount
    final hasReadyProducts = products.any((p) =>
        p.name.isNotEmpty &&
        p.price.isNotEmpty &&
        _parsePriceAmount(p.price) != null);
    final isInventoryMode = !hasReadyProducts;

    final blogDraft = session.blogDraft ?? _generateBlogDraft(products, session.businessType);

    return {
      'schemaVersion': 'xrex.catalog.v1',
      'source': 'xrex',
      'exportType': isInventoryMode ? 'visual_inventory' : 'catalog_draft',
      'mode': isInventoryMode ? 'visual_inventory' : 'catalog_draft',
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
      if (isInventoryMode) 'blogDraft': blogDraft.toJson(),
    };
  }

  XRexBlogDraft _generateBlogDraft(List<XRexDraftProduct> products, String businessType) {
    String category = businessType;
    if (category == 'Fotoğraf/metin bekleniyor' || category == 'Belirlenmedi' || category == 'Genel') {
      final categoryCounts = <String, int>{};
      for (final p in products) {
        if (p.category.isNotEmpty) {
          categoryCounts[p.category] = (categoryCounts[p.category] ?? 0) + 1;
        }
      }
      if (categoryCounts.isNotEmpty) {
        category = categoryCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }
    }

    final lowerCat = category.toLowerCase();
    if (lowerCat.contains('giyim') || lowerCat.contains('butik')) {
      return const XRexBlogDraft(
        title: 'Sezonun En Şık Giyim Trendleri ve Kombin Önerileri',
        summary: 'Gardırobunuzu yenilerken dikkat etmeniz gereken ipuçları, stil tüyoları ve sezonun öne çıkan parçaları.',
        sections: [
          XRexBlogSection(
            title: '1. Temel Parçalarla Şıklığı Yakalayın',
            content: 'Gardırobunuzun kurtarıcısı olacak keten elbiseler, pamuklu gömlekler ve rahat kesim pantolonlar ile günlük şıklığı yakalamak artık çok kolay. Doğru kumaş seçimi hem konforunuzu artırır hem de tarzınızı yansıtır.',
          ),
          XRexBlogSection(
            title: '2. Renk ve Doku Uyumu',
            content: 'Bu sezon pastel tonlar ve doğal keten dokuları bir arada kullanılarak yumuşak ama iddialı geçişler sağlanıyor. Aksesuarlarınızla kontrast yaratarak stilinizi hareketlendirebilirsiniz.',
          ),
        ],
        faq: [
          XRexBlogFaq(
            question: 'Keten kıyafetler nasıl yıkanmalıdır?',
            answer: 'Keten kumaşların ömrünü uzatmak için düşük sıcaklıkta (30 derece) ve hassas programda yıkanması önerilir.',
          ),
          XRexBlogFaq(
            question: 'Vücut tipine göre doğru elbise seçimi nasıl yapılır?',
            answer: 'Kemerli elbiseler bel bölgesini vurgulayarak daha dengeli bir silüet çizerken, A kesim elbiseler konforlu bir kullanım sunar.',
          ),
        ],
        metaDescription: 'Sezonun en şık giyim trendleri, kombin önerileri ve stil ipuçları bu rehberde. Hemen okuyun ve tarzınızı güncelleyin!',
        keywords: ['giyim trendleri', 'kombin önerileri', 'elbise modelleri', 'stil tüyoları', 'keten giyim'],
        suggestedStoreCategory: 'Giyim & Aksesuar',
      );
    } else if (lowerCat.contains('kozmetik')) {
      return const XRexBlogDraft(
        title: 'Kişisel Bakım ve Günlük Cilt Bakımı Rutini Rehberi',
        summary: 'Sağlıklı ve parlak bir cilt için adım adım bakım önerileri, doğru ürün kullanımı ve kozmetik tüyoları.',
        sections: [
          XRexBlogSection(
            title: '1. Cilt Temizliği ve Nemlendirme',
            content: 'Cilt bakımının temeli temizlikten geçer. Cildinize uygun tonik ve kremlerle yapacağınız günlük temizlik gözenekleri arındırır. Ardından uygulayacağınız nemlendirici, cildin nem dengesini korur.',
          ),
          XRexBlogSection(
            title: '2. Serum ve Özel Bakım Kürleri',
            content: 'Cildinizin ihtiyacına göre C vitamini, hyaluronik asit veya retinol içeren serumları bakım rutininize ekleyerek lekelerle savaşabilir ve yaşlanma belirtilerini geciktirebilirsiniz.',
          ),
        ],
        faq: [
          XRexBlogFaq(
            question: 'Güneş kremi hangi aşamada sürülmelidir?',
            answer: 'Güneş kremi, cilt bakım rutininizin en son adımı olarak nemlendiriciden sonra sürülmeli ve gün içinde yenilenmelidir.',
          ),
          XRexBlogFaq(
            question: 'Cilt tipimi nasıl öğrenebilirim?',
            answer: 'Yıkama sonrası cildinizde gerginlik oluyorsa kuru, T bölgesinde parlama varsa karma veya yağlı cilt tipine sahipsiniz demektir.',
          ),
        ],
        metaDescription: 'Günlük cilt bakımı nasıl olmalı? En etkili kozmetik ürünler, nemlendirici rehberi ve bakım tüyoları yazımızda.',
        keywords: ['cilt bakımı', 'kozmetik', 'nemlendirici krem', 'cilt bakım rutini', 'serum önerileri'],
        suggestedStoreCategory: 'Kozmetik & Kişisel Bakım',
      );
    } else if (lowerCat.contains('gözlük')) {
      return const XRexBlogDraft(
        title: 'Yüz Şekline Göre Gözlük Seçimi ve Stil Rehberi',
        summary: 'Hem göz sağlığınızı koruyacak hem de tarzınızı tamamlayacak en doğru gözlük modelini bulma rehberi.',
        sections: [
          XRexBlogSection(
            title: '1. Yüz Tipinizi Belirleyin',
            content: 'Yuvarlak yüz hatlarına sahipseniz köşeli çerçeveler yüzünüzü dengeler. Kare yüzler için ise oval veya yuvarlak gözlük modelleri hatları yumuşatmak için idealdir.',
          ),
          XRexBlogSection(
            title: '2. Cam ve Filtre Teknolojileri',
            content: 'Gözlük alırken sadece çerçeveye değil, UV400 korumasına ve polarize filtre özelliklerine dikkat etmelisiniz. Bu camlar parlamaları önleyerek sürüş konforunu artırır.',
          ),
        ],
        faq: [
          XRexBlogFaq(
            question: 'Polarize cam ile normal cam arasındaki fark nedir?',
            answer: 'Polarize camlar yatay yüzeylerden yansıyan parlamaları (su, kar, asfalt) filtreler, normal camlar ise sadece ışık yoğunluğunu azaltır.',
          ),
          XRexBlogFaq(
            question: 'Gözlük camı nasıl temizlenmelidir?',
            answer: 'Özel mikrofiber bezler ve temizleme spreyi kullanılmalı; kıyafet ucu gibi sert dokularla cam çizilmemelidir.',
          ),
        ],
        metaDescription: 'Yüz şeklinize en uygun gözlük hangisi? Polarize cam özellikleri, güneş gözlüğü modası ve çerçeve seçim ipuçları.',
        keywords: ['güneş gözlüğü', 'gözlük seçimi', 'çerçeve modelleri', 'polarize cam', 'stil rehberi'],
        suggestedStoreCategory: 'Gözlük & Aksesuar',
      );
    } else if (lowerCat.contains('mobilya')) {
      return const XRexBlogDraft(
        title: 'Ev Dekorasyonunda Mobilya Seçimi ve Alan Yönetimi',
        summary: 'Yaşam alanlarınızı daha geniş ve fonksiyonel göstermek için mobilya yerleşim tüyoları ve modern tasarım fikirleri.',
        sections: [
          XRexBlogSection(
            title: '1. Küçük Odalar İçin Çok Fonksiyonlu Çözümler',
            content: 'Sandıklı puf modelleri, açılır masalar ve modüler koltuk takımları dar alanları en verimli şekilde kullanmanıza olanak tanır. Açık renk mobilyalar ise odayı ferah gösterir.',
          ),
          XRexBlogSection(
            title: '2. Doğal Ahşap ve Metalin Kombinasyonu',
            content: 'Modern endüstriyel tasarımlarda ahşap sıcaklığı ile metalin soğuk şıklığı bir araya getirilerek dengeli bir dekorasyon stili elde ediliyor.',
          ),
        ],
        faq: [
          XRexBlogFaq(
            question: 'Mobilya alırken nelere dikkat edilmeli?',
            answer: 'Malzeme kalitesi, iskelet sağlamlığı, kumaş silinebilirliği ve evinizin ölçülerine uygunluğu öncelikli olmalıdır.',
          ),
          XRexBlogFaq(
            question: 'Ahşap mobilya bakımı nasıl yapılır?',
            answer: 'Hafif nemli bir bezle silindikten sonra kurulanmalı ve direkt güneş ışığından uzak tutulmalıdır.',
          ),
        ],
        metaDescription: 'Ev dekorasyonu için pratik mobilya yerleşim önerileri ve modern tasarım fikirleri rehberimizde.',
        keywords: ['mobilya seçimi', 'ev dekorasyonu', 'koltuk takımı', 'ahşap mobilya', 'alan yönetimi'],
        suggestedStoreCategory: 'Ev & Mobilya',
      );
    } else {
      return const XRexBlogDraft(
        title: 'Bilinçli Alışveriş ve En Doğru Ürün Seçim Rehberi',
        summary: 'İhtiyacınıza en uygun ürün gruplarını belirlemek, kalite kontrolü yapmak ve bütçenizi yönetmek için alışveriş ipuçları.',
        sections: [
          XRexBlogSection(
            title: '1. İhtiyaç Analizi Yapın',
            content: 'Alışverişe çıkmadan önce listenizi hazırlamak ve bütçe planlaması yapmak gereksiz harcamaları önler. Alacağınız ürünlerin uzun ömürlü olması fiyat-performans dengesini korur.',
          ),
          XRexBlogSection(
            title: '2. Kullanıcı Yorumları ve İncelemeler',
            content: 'Bir ürünü satın almadan önce diğer kullanıcıların deneyimlerini incelemek, ürünün gerçek kalitesi hakkında en doğru bilgiyi verir.',
          ),
        ],
        faq: [
          XRexBlogFaq(
            question: 'İnternet alışverişlerinde nelere dikkat edilmelidir?',
            answer: 'Güvenli ödeme yöntemleri (3D Secure), satıcı puanı ve iade koşullarının kolaylığı kontrol edilmelidir.',
          ),
        ],
        metaDescription: 'Bilinçli alışveriş yapmanın püf noktaları, bütçe yönetimi ve ürün inceleme tüyoları bu yazıda.',
        keywords: ['alışveriş tüyoları', 'ürün seçimi', 'bütçe planlama', 'kalite rehberi'],
        suggestedStoreCategory: 'Genel Alışveriş',
      );
    }
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
    final sourceLines =
        product.sourceLineSummary
            ?.split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList() ??
        const <String>[];
    final warnings = <String>[
      ...product.parserWarnings,
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
        'oldRaw':
            product.oldPrice.trim().isEmpty ? null : product.oldPrice.trim(),
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
        'detectionId': product.detectionId,
        'crop': null,
      },
      'origin': {
        'createdBy': product.origin,
        'confidence': product.confidence,
        'sourceLines': sourceLines,
      },
      'review': {'needsUserReview': true, 'warnings': warnings},
    };
  }

  num? _parsePriceAmount(String rawPrice) {
    return XRexPriceParser.parseAmount(rawPrice);
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
