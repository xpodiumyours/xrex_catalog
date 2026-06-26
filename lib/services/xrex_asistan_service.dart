import '../models/xrex_chat_message.dart';
import '../models/xrex_draft_product.dart';
import 'xrex_price_parser.dart';

class XRexAsistanService {
  const XRexAsistanService();

  XRexChatMessage generateResponse(String input, {XRexDraftProduct? activeProduct}) {
    final lower = input.toLowerCase();

    // 1. Price Update Intent
    if (_containsAny(lower, ['fiyat', 'tl', 'ücret', 'olsun', 'yap'])) {
      final amount = XRexPriceParser.parseAmount(input);
      if (amount != null && activeProduct != null) {
        activeProduct.price = amount.toString();
        return XRexChatMessage(
          text: "Tamam, ${activeProduct.name} ürününün fiyatını $amount TL olarak güncelledim. Başka bir değişiklik var mı?",
          type: XRexMessageType.actionResult,
          quickReplies: [
            const XRexQuickReply(label: "Kataloğu Bitir", payload: "EXPORT_JSON"),
            const XRexQuickReply(label: "Başka Ürün Bak", payload: "REVIEW_PRODUCTS"),
          ],
        );
      }
    }

    // 2. Name Update Intent
    if (_containsAny(lower, ['adı', 'ismini', 'olsun', 'değiştir']) && activeProduct != null) {
       return XRexChatMessage(
          text: "Yeni ismi ne olsun? Hemen düzelteyim.",
          quickReplies: [const XRexQuickReply(label: "Vazgeç", payload: "CANCEL")],
        );
    }

    // 3. General Help / Greetings / Action Keywords
    if (_containsAny(lower, ['merhaba', 'selam', 'hey', 'nasılsın', 'başla'])) {
      return XRexChatMessage(
        text: "Selam! Ben XRex Asistan. Fotoğrafını çektiğin ürünleri senin için hızlıca kataloğa dönüştürebilirim. Başlamak için alt bardaki fotoğraf simgesine basıp bir fotoğraf yükle!",
      );
    }

    if (_containsAny(lower, ['fotoğraf', 'analiz', 'resim', 'çek'])) {
       return XRexChatMessage(
        text: "Harika! Analiz için alt bardaki fotoğraf butonuna basarak galeriden bir fotoğraf seçebilirsin veya yeni bir tane çekebilirsin.",
      );
    }

    if (_containsAny(lower, ['liste', 'ürünler', 'göster', 'bak'])) {
       return XRexChatMessage(
        text: "Tabii, bulduğumuz tüm ürünleri 'Ürün Listesi' sekmesinde görebilir ve düzenleyebilirsin.",
        quickReplies: [const XRexQuickReply(label: "Listeye Git", payload: "REVIEW_PRODUCTS")],
      );
    }

    if (_containsAny(lower, ['katalog', 'bitir', 'json', 'hazırla'])) {
      return XRexChatMessage(
        text: "Kataloğun hazır gibi görünüyor! Ürünleri otomatik kategorilere ayırayım mı yoksa direkt çıktı mı almak istersin?",
        quickReplies: [
          const XRexQuickReply(label: "Kategorilere Ayır", payload: "CATEGORIZE"),
          const XRexQuickReply(label: "JSON Çıktısı Al", payload: "EXPORT_JSON"),
        ],
      );
    }

    // Default response
    return XRexChatMessage(
      text: "Seni tam anlayamadım ama katalog oluşturmanda yardımcı olabilirim. Ne yapmak istersin?",
      quickReplies: [
        const XRexQuickReply(label: "Ürün Listesini Gör", payload: "REVIEW_PRODUCTS"),
      ],
    );
  }

  XRexChatMessage handleAnalysisResult(int productCount) {
    if (productCount == 0) {
      return XRexChatMessage(
        text: "Görseli inceledim ama net bir ürün veya fiyat çıkaramadım. İstersen metni elle girebilirsin veya alt bardaki fotoğraf butonuyla başka bir fotoğraf deneyebiliriz.",
        quickReplies: [
          const XRexQuickReply(label: "Metin Yapıştır", payload: "PASTE_TEXT"),
        ],
      );
    }

    return XRexChatMessage(
      text: "Analiz tamamlandı! Görselde $productCount tane ürün buldum ve taslaklarını hazırladım. İlk üründen incelemeye başlayalım mı?",
      quickReplies: [
        const XRexQuickReply(label: "Ürünleri İncele", payload: "REVIEW_PRODUCTS"),
        const XRexQuickReply(label: "Hepsini Onayla", payload: "CONFIRM_ALL"),
      ],
    );
  }

  bool _containsAny(String value, List<String> needles) {
    return needles.any((n) => value.contains(n));
  }
}
