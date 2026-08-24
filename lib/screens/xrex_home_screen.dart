import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/xrex_chat_message.dart';
import '../models/xrex_detected_region.dart';
import '../models/xrex_draft_product.dart';
import '../models/xrex_catalog_session.dart';
import '../services/xrex_asistan_service.dart';
import '../services/xrex_catalog_analyzer_service.dart';
import '../services/xrex_catalog_service.dart';
import '../services/xrex_portfolio_service.dart';
import '../services/xrex_supabase_service.dart';
import '../widgets/xrex_chat_bubble.dart';
import '../widgets/xrex_product_table.dart';

class XRexHomeScreen extends StatefulWidget {
  const XRexHomeScreen({super.key});

  @override
  State<XRexHomeScreen> createState() => _XRexHomeScreenState();
}

class _XRexHomeScreenState extends State<XRexHomeScreen> {
  // Services
  final XRexAsistanService asistanService = const XRexAsistanService();
  final XRexCatalogAnalyzerService analyzerService = XRexCatalogAnalyzerService();
  final XRexCatalogService catalogService = const XRexCatalogService();
  final XRexSupabaseService supabaseService = XRexSupabaseService();

  // Data State
  final List<XRexChatMessage> chatMessages = [];
  final List<XRexDraftProduct> products = [];
  final Map<String, TextEditingController> nameControllers = {};
  final Map<String, TextEditingController> priceControllers = {};
  final Map<String, TextEditingController> descriptionControllers = {};

  Uint8List? selectedImageBytes;
  String? selectedImagePath;
  Size? selectedImageSize;
  List<XRexDetectedRegion> detectedRegions = [];

  // UI State
  final TextEditingController chatController = TextEditingController();
  final ScrollController chatScrollController = ScrollController();
  final TextEditingController sheetUrlController = TextEditingController(
    text: 'https://docs.google.com/spreadsheets/d/1FDg2nTK_C1r346QhhoRYQMLRetnEHTLRFz2yVxiUXE/edit#gid=1984083474',
  );
  final TextEditingController portfolioSearchController = TextEditingController();
  bool isBotThinking = false;
  bool isSyncingSheet = false;
  int activeTabIndex = 0; // 0: Chat, 1: Görsel/Liste, 2: Portföy

  @override
  void initState() {
    super.initState();
    // Karşılama mesajı
    _addBotMessage(
      "Merhaba! Ben XRex Asistan. Fotoğrafını çektiğin ürünleri senin için hızlıca kataloğa dönüştürebilirim. Başlamak için alt bardaki fotoğraf butonuna basarak bir fotoğraf yükleyebilirsin.",
    );
  }

  @override
  void dispose() {
    for (var c in nameControllers.values) {
      c.dispose();
    }
    for (var c in priceControllers.values) {
      c.dispose();
    }
    for (var c in descriptionControllers.values) {
      c.dispose();
    }
    chatController.dispose();
    chatScrollController.dispose();
    sheetUrlController.dispose();
    portfolioSearchController.dispose();
    super.dispose();
  }

  void _addBotMessage(
    String text, {
    List<XRexQuickReply> replies = const [],
    XRexMessageType type = XRexMessageType.text,
  }) {
    setState(() {
      isBotThinking = false;
      chatMessages.add(
        XRexChatMessage(
          text: text,
          isBot: true,
          type: type,
          quickReplies: replies,
        ),
      );
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      chatMessages.add(XRexChatMessage(text: text, isBot: false));
      isBotThinking = true;
    });
    _scrollToBottom();
    _handleUserInput(text);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatScrollController.hasClients) {
        chatScrollController.animateTo(
          chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _ensureControllers(XRexDraftProduct product) {
    nameControllers.putIfAbsent(
      product.id,
      () => TextEditingController(text: product.name),
    );
    priceControllers.putIfAbsent(
      product.id,
      () => TextEditingController(text: product.price),
    );
    descriptionControllers.putIfAbsent(
      product.id,
      () => TextEditingController(text: product.description),
    );
  }

  Future<void> _handleUserInput(String input) async {
    final response = asistanService.generateResponse(
      input,
      activeProduct: products.isNotEmpty ? products.last : null,
    );

    await Future.delayed(const Duration(milliseconds: 600)); // Doğal gecikme
    setState(() {
      chatMessages.add(response);
      isBotThinking = false;
    });
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) return;

      if (kIsWeb) {
        _addBotMessage(
          "⚠️ Uyarı: Web sürümünde yapay zeka destekli OCR çalışmaz. Taranan çöp veriler engellenecektir. Gerçek test için Android veya iOS uygulamasını kullanın.",
        );
        await Future.delayed(const Duration(seconds: 2));
      }

      final imageSize = await _decodeImageSize(bytes);

      setState(() {
        selectedImageBytes = bytes;
        selectedImagePath = kIsWeb ? null : result.files.single.path;
        selectedImageSize = imageSize;
      });

      _addBotMessage(
        "Fotoğrafı aldım! Şimdi ürünleri tespit etmek için analiz ediyorum...",
        type: XRexMessageType.image,
      );
      _analyzePhoto();
    } catch (e) {
      _addBotMessage("Fotoğraf yüklenirken bir hata oluştu: $e");
    }
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          "Çalışma Alanını Sıfırla",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Mevcut ürün listesini ve mesaj geçmişini tamamen temizlemek istediğinden emin misin?",
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _resetState();
            },
            child: const Text("Temizle"),
          ),
        ],
      ),
    );
  }

  void _resetState() {
    setState(() {
      products.clear();
      chatMessages.clear();
      detectedRegions.clear();
      selectedImageBytes = null;
      selectedImagePath = null;
      for (var c in nameControllers.values) {
        c.dispose();
      }
      for (var c in priceControllers.values) {
        c.dispose();
      }
      for (var c in descriptionControllers.values) {
        c.dispose();
      }
      nameControllers.clear();
      priceControllers.clear();
      descriptionControllers.clear();
    });
    _addBotMessage(
      "Selam! Yeni bir analiz için hazırım. Fotoğraf yükleyebilirsin.",
    );
  }

  Future<void> _analyzePhoto() async {
    if (selectedImagePath == null && selectedImageBytes == null) return;
    setState(() => isBotThinking = true);

    try {
      final result = await analyzerService.analyzeImagePath(
        selectedImagePath ?? '',
        imageBytes: selectedImageBytes,
      );

      // Filter out low confidence or likely junk products before adding
      final filteredProducts =
          result.products
              .where((p) => p.name != 'İsimsiz ürün' && p.name.length > 2)
              .toList();

      setState(() {
        for (var p in filteredProducts) {
          _ensureControllers(p);
        }
        products.addAll(filteredProducts);
        detectedRegions = result.regions;
      });

      final response = asistanService.handleAnalysisResult(
        filteredProducts.length,
      );
      _addBotMessage(
        response.text,
        replies: [
          ...response.quickReplies,
          const XRexQuickReply(
            label: "Katalog Haline Getir",
            payload: "EXPORT_JSON",
          ),
        ],
      );

      // Ürünleri tek tek listele (Kart olarak)
      if (filteredProducts.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        for (var i = 0; i < filteredProducts.length; i++) {
          if (i >= 5) {
            // Çok fazla ürün varsa ilk 5'i göster
            _addBotMessage(
              "...ve diğer ${filteredProducts.length - 5} ürün daha bulundu. Hepsini 'Ürün Listesi' tabında görebilirsin.",
            );
            break;
          }
          final p = filteredProducts[i];
          setState(() {
            chatMessages.add(
              XRexChatMessage(
                text: "Ürün Bulundu",
                type: XRexMessageType.productCard,
                associatedProduct: p,
                isBot: true,
              ),
            );
            isBotThinking = false;
          });
          _scrollToBottom();
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    } catch (e) {
      _addBotMessage("Analiz sırasında bir sorun çıktı: $e");
    }
  }

  Future<Size?> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    return size;
  }

  void _handleQuickReply(XRexQuickReply reply) {
    _addUserMessage(reply.label);

    if (reply.payload == "PICK_IMAGE") {
      _pickImage();
    } else if (reply.payload == "REVIEW_PRODUCTS") {
      setState(() => activeTabIndex = 1);
    } else if (reply.payload == "EXPORT_JSON") {
      _prepareCatalogDraft();
    } else if (reply.payload == "CATEGORIZE") {
      _categorizeProducts();
    } else if (reply.payload == "ANALYZE_PHOTO") {
      _pickImage();
    } else if (reply.payload == "LIST_PRODUCTS") {
      setState(() => activeTabIndex = 1);
    }
  }

  void _categorizeProducts() {
    setState(() {
      for (var p in products) {
        if (p.category == 'Genel' || p.category.isEmpty) {
          p.category = analyzerService.inferCategory(p.name);
          _ensureControllers(p);
        }
      }
    });
    _addBotMessage(
      "Ürünleri isimlerine göre gruplandırdım ve kategorilerini güncelledim. 'Ürün Listesi' kısmından kontrol edebilirsin.",
      replies: [
        const XRexQuickReply(label: "Listeyi Gör", payload: "REVIEW_PRODUCTS"),
        const XRexQuickReply(label: "Kataloğu Bitir", payload: "EXPORT_JSON"),
      ],
    );
  }

  void _prepareCatalogDraft() {
    final validProducts = catalogService.validProducts(products);
    if (validProducts.isEmpty) {
      _addBotMessage(
        "Taslak hazırlamak için en az 1 ürün doldurmalısın. İstersen Ürün Listesi tabından eksikleri tamamlayabilirsin.",
      );
      return;
    }

    // Show a premium progress overlay loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          backgroundColor: Color(0xFF0F172A),
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF06B6D4)),
              SizedBox(width: 20),
              Text(
                "Supabase veritaban\u{0131}na aktar\u{0131}l\u{0131}yor...",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );

    // Call Supabase upload service
    supabaseService.uploadProducts(validProducts).then((success) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (success) {
        // Show success alert
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text(
                "Aktar\u{0131}m Ba\u{015f}ar\u{0131}l\u{0131}",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              content: const Text(
                "T\u{00fc}m \u{00fc}r\u{00fc}nler ba\u{015f}ar\u{0131}yla Supabase veritaban\u{0131}na kaydedildi! \u2705",
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Clear the scanned draft products list since they are saved
                    setState(() {
                      products.clear();
                      nameControllers.clear();
                      priceControllers.clear();
                      descriptionControllers.clear();
                      activeTabIndex = 0; // Return to assistant tab
                    });
                    _addBotMessage(
                      "Harika! \u{00dc}r\u{00fc}nler do\u{011f}rudan Supabase veritaban\u{0131}na aktar\u{0131}ld\u{0131}. Yeni bir katalog taramas\u{0131} i\u{00e7}in haz\u{0131}r\u{0131}z.",
                    );
                  },
                  child: const Text("Harika!"),
                ),
              ],
            );
          },
        );
      } else {
        // Supabase direct connection failed - fallback to manual JSON Copy dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF7F1D1D),
            content: Text(
              "Supabase ba\u{011f}lant\u{0131}s\u{0131} sa\u{011f}lanamad\u{0131}. Manuel JSON kopyalama ekran\u{0131} a\u{00e7}\u{0131}l\u{0131}yor. \u274c",
            ),
          ),
        );

        final session = XRexCatalogSession(
          sessionId: DateTime.now().microsecondsSinceEpoch.toString(),
          businessType: "Belirlenmedi",
          selectedImageBytes: selectedImageBytes,
          selectedImagePath: selectedImagePath,
          ocrRawText: "",
          products: validProducts,
        );
        final formattedJson = catalogService.formattedJson(session);

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text(
                "Katalog Tasla\u{011f}\u{0131} (Manuel Yedek)",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Supabase ba\u{011f}lant\u{0131}s\u{0131} başar\u{0131}s\u{0131}z oldu\u{011f}u i\u{00e7}in JSON verisini kopyalayarak manuel aktarabilirsiniz.",
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF020617),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x3322D3EE)),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          formattedJson,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Kapat"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: formattedJson));
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _addBotMessage(
                      "Katalog JSON verisi panoya kopyaland\u{0131}! \u2705",
                    );
                  },
                  child: const Text("JSON Kopyala"),
                ),
              ],
            );
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04080F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.25,
            colors: [Color(0xFF083344), Color(0xFF071428), Color(0xFF04080F)],
            stops: [0, 0.46, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildMinimalHeader(),
              _buildWorkflowBar(),
              Expanded(
                child: IndexedStack(
                  index: activeTabIndex,
                  children: [
                    _buildChatView(),
                    _buildListView(),
                    _buildPortfolioView(),
                  ],
                ),
              ),
              if (activeTabIndex == 0) _buildFloatingChatInput(),
              if (activeTabIndex == 1 && products.isNotEmpty)
                _buildBottomActionOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xE6090D18),
        border: const Border(
          bottom: BorderSide(color: Color(0x2219D3EE), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22D3EE), Color(0xFF0891B2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    "XR",
                    style: TextStyle(
                      color: Color(0xFF04080F),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "XREX Catalog",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "AI katalog çalışma alanı",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF67E8F9),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white38),
                tooltip: 'Çalışma Alanını Sıfırla',
                onPressed: _confirmReset,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 38,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1F2A3D)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildHeaderTabItem(0, "Asistan")),
                Expanded(child: _buildHeaderTabItem(1, "Ürün Listesi")),
                Expanded(child: _buildHeaderTabItem(2, "Portf\u{00f6}y")),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildWorkflowChip(
            Icons.add_a_photo_outlined,
            "Fotoğraf yükle",
            products.isEmpty,
          ),
          _buildWorkflowChip(
            Icons.manage_search_rounded,
            "Ürünleri kontrol et",
            products.isNotEmpty,
          ),
          _buildWorkflowChip(
            Icons.content_copy_rounded,
            "JSON hazırla",
            products.isNotEmpty && activeTabIndex == 1,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowChip(IconData icon, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            active
                ? const Color(0xFF06B6D4).withValues(alpha: 0.14)
                : const Color(0xFF0B1220).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? const Color(0xFF22D3EE) : const Color(0xFF1F2A3D),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: active ? const Color(0xFF22D3EE) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFFE0F7FF) : const Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTabItem(int index, String label) {
    final isSelected = activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => activeTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF22D3EE) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF031018) : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (index == 1 && products.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${products.length}",
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionOverlay() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFF04080F), Color(0x0004080F)],
        ),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF06B6D4),
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 8,
          shadowColor: const Color(0xFF06B6D4).withValues(alpha: 0.4),
        ),
        onPressed: _prepareCatalogDraft,
        child: const Text(
          "Kataloğu Onayla ve JSON Hazırla",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildChatView() {
    return ListView.builder(
      controller: chatScrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      itemCount: chatMessages.length + (isBotThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatMessages.length && isBotThinking) {
          return _buildThinkingIndicator();
        }
        final message = chatMessages[index];
        return Column(
          crossAxisAlignment:
              message.isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            XRexChatBubble(message: message),
            if (message.isBot &&
                message.quickReplies.isNotEmpty &&
                index == chatMessages.length - 1)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Wrap(
                  spacing: 8,
                  children:
                      message.quickReplies.map((reply) {
                        return ActionChip(
                          backgroundColor: const Color(0xFF0B1220),
                          side: const BorderSide(color: Color(0xFF22D3EE)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          label: Text(
                            reply.label,
                            style: const TextStyle(
                              color: Color(0xFF67E8F9),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () => _handleQuickReply(reply),
                        );
                      }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Color(0xFF06B6D4),
            ),
          ),
          const SizedBox(width: 12),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF06B6D4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xCC0B1220),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x3322D3EE)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x5522D3EE)),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    size: 28,
                    color: Color(0xFF22D3EE),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Katalog için ürün bekleniyor",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Fotoğraf yükle, XRex ürünleri bulsun; sonra burada hızlıca düzenle.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text("Fotoğraf Yükle"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: XRexProductTable(
        products: products,
        isTableView: false,
        nameControllers: nameControllers,
        priceControllers: priceControllers,
        descriptionControllers: descriptionControllers,
        onChanged: (p) => setState(() {}),
        onDuplicate: (p) {
          final dup = p.copyWith(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
          );
          setState(() {
            _ensureControllers(dup);
            products.add(dup);
          });
        },
        onRemove:
            (p) => setState(() {
              products.removeWhere((i) => i.id == p.id);
            }),
        getWarnings: (p) => [],
      ),
    );
  }

  Widget _buildFloatingChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xF20B1220),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x3322D3EE)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF06B6D4)),
              tooltip: 'Fotoğraf Yükle / Çek',
              onPressed: _pickImage,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: chatController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: "Bir şeyler yazın...",
                  hintStyle: TextStyle(color: Colors.white10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  isDense: true,
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    _addUserMessage(val);
                    chatController.clear();
                  }
                },
              ),
            ),
            GestureDetector(
              onTap: () {
                if (chatController.text.trim().isNotEmpty) {
                  _addUserMessage(chatController.text);
                  chatController.clear();
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF06B6D4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioView() {
    final portfolioService = XRexPortfolioService();
    final allProducts = portfolioService.products;
    final searchQuery = portfolioSearchController.text.trim().toLowerCase();

    final filteredProducts = allProducts.where((p) {
      if (searchQuery.isEmpty) return true;
      final simplifiedQuery = searchQuery
          .replaceAll('\u{011f}', 'g')
          .replaceAll('\u{00fc}', 'u')
          .replaceAll('\u{015f}', 's')
          .replaceAll('\u{0131}', 'i')
          .replaceAll('\u{00f6}', 'o')
          .replaceAll('\u{00e7}', 'c');
      final nameSimp = p.name.toLowerCase()
          .replaceAll('\u{011f}', 'g')
          .replaceAll('\u{00fc}', 'u')
          .replaceAll('\u{015f}', 's')
          .replaceAll('\u{0131}', 'i')
          .replaceAll('\u{00f6}', 'o')
          .replaceAll('\u{00e7}', 'c');
      final catSimp = p.category.toLowerCase()
          .replaceAll('\u{011f}', 'g')
          .replaceAll('\u{00fc}', 'u')
          .replaceAll('\u{015f}', 's')
          .replaceAll('\u{0131}', 'i')
          .replaceAll('\u{00f6}', 'o')
          .replaceAll('\u{00e7}', 'c');
      
      if (nameSimp.contains(simplifiedQuery) || catSimp.contains(simplifiedQuery)) return true;
      for (final alias in p.aliases) {
        final aliasSimp = alias.toLowerCase()
            .replaceAll('\u{011f}', 'g')
            .replaceAll('\u{00fc}', 'u')
            .replaceAll('\u{015f}', 's')
            .replaceAll('\u{0131}', 'i')
            .replaceAll('\u{00f6}', 'o')
            .replaceAll('\u{00e7}', 'c');
        if (aliasSimp.contains(simplifiedQuery)) return true;
      }
      return false;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sheet configuration card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xCC0B1220),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x3322D3EE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.table_chart_outlined,
                        size: 20,
                        color: Color(0xFF22D3EE),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Google Sheets Entegrasyonu",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Ürün listenizi canlı olarak senkronize edin",
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sheetUrlController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: "Google Sheet Paylaşım Bağlantısı",
                    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    hintText: "https://docs.google.com/spreadsheets/d/.../edit",
                    hintStyle: const TextStyle(color: Colors.white10),
                    filled: true,
                    fillColor: const Color(0xFF020617),
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1F2A3D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF06B6D4)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: isSyncingSheet ? null : () async {
                    setState(() => isSyncingSheet = true);
                    final success = await portfolioService.syncFromGoogleSheet(
                      sheetUrlController.text,
                    );
                    setState(() => isSyncingSheet = false);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: success ? const Color(0xFF064E3B) : const Color(0xFF7F1D1D),
                        content: Text(
                          success
                              ? "Eşleştirme Başarılı! ${portfolioService.products.length} ürün portföye yüklendi. \u2705"
                              : "Hata! Google Sheets bağlantısını ve paylaşım ayarlarını kontrol edin. \u274c",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                  icon: isSyncingSheet
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(
                    isSyncingSheet ? "Eşitleniyor..." : "Tablodan Verileri Güncelle 🔄",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          portfolioService.products.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF1E293B),
                            content: Text("Portf\u{00f6}y tamamen temizlendi. \u2705"),
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text(
                        "Portf\u{00f6}y\u{00fc} Temizle",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (portfolioService.lastSyncTime != null)
                      Text(
                        "Son g\u{00fc}ncelleme: ${portfolioService.lastSyncTime!.hour.toString().padLeft(2, '0')}:${portfolioService.lastSyncTime!.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Search bar
          TextField(
            controller: portfolioSearchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Portföyde ara (isim, kategori, takma ad)...",
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF06B6D4)),
              filled: true,
              fillColor: const Color(0x7F0B1220),
              isDense: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF1F2A3D)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF06B6D4)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Products list
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_rounded, color: Colors.white24, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          allProducts.isEmpty
                              ? "Henüz portföy yüklenmemiş"
                              : "Aramayla eşleşen ürün bulunamadı",
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final p = filteredProducts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1220).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF1F2A3D)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0891B2).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFF22D3EE).withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          p.category,
                                          style: const TextStyle(
                                            color: Color(0xFF67E8F9),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (p.description.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      p.description,
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  if (p.aliases.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: p.aliases.map((alias) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            alias,
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white24,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  portfolioService.products.removeWhere((item) => item.id == p.id);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
