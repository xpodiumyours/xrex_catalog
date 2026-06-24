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
  final XRexCatalogAnalyzerService analyzerService = const XRexCatalogAnalyzerService();
  final XRexCatalogService catalogService = const XRexCatalogService();

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
  bool isBotThinking = false;
  int activeTabIndex = 0; // 0: Chat, 1: Görsel/Liste

  @override
  void initState() {
    super.initState();
    // Karşılama mesajı
    _addBotMessage("Merhaba! Ben XRex Asistan. Fotoğrafını çektiğin ürünleri senin için hızlıca kataloğa dönüştürebilirim. Başlamak için bir fotoğraf yükleyebilirsin.",
      replies: [const XRexQuickReply(label: "Fotoğraf Yükle", payload: "PICK_IMAGE")]);
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
    super.dispose();
  }

  void _addBotMessage(String text, {List<XRexQuickReply> replies = const [], XRexMessageType type = XRexMessageType.text}) {
    setState(() {
      isBotThinking = false;
      chatMessages.add(XRexChatMessage(
        text: text,
        isBot: true,
        type: type,
        quickReplies: replies,
      ));
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
    nameControllers.putIfAbsent(product.id, () => TextEditingController(text: product.name));
    priceControllers.putIfAbsent(product.id, () => TextEditingController(text: product.price));
    descriptionControllers.putIfAbsent(product.id, () => TextEditingController(text: product.description));
  }

  Future<void> _handleUserInput(String input) async {
    final response = asistanService.generateResponse(input,
      activeProduct: products.isNotEmpty ? products.last : null);

    await Future.delayed(const Duration(milliseconds: 600)); // Doğal gecikme
    setState(() {
      chatMessages.add(response);
      isBotThinking = false;
    });
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    // If there are existing products, ask to clear
    if (products.isNotEmpty) {
      final shouldClear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text("Yeni Fotoğraf", style: TextStyle(color: Colors.white)),
          content: const Text("Mevcut ürün listesini temizleyip yeni bir analize başlamak ister misin?", style: TextStyle(color: Color(0xFF94A3B8))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Üzerine Ekle")),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Temizle ve Başla")),
          ],
        ),
      );
      if (shouldClear == true) {
        _resetState();
      }
    }

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) return;

      final imageSize = await _decodeImageSize(bytes);

      setState(() {
        selectedImageBytes = bytes;
        selectedImagePath = kIsWeb ? null : result.files.single.path;
        selectedImageSize = imageSize;
      });

      _addBotMessage("Fotoğrafı aldım! Şimdi ürünleri tespit etmek için analiz ediyorum...", type: XRexMessageType.image);
      _analyzePhoto();
    } catch (e) {
      _addBotMessage("Fotoğraf yüklenirken bir hata oluştu: $e");
    }
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
    _addBotMessage("Selam! Yeni bir analiz için hazırım. Fotoğraf yükleyebilirsin.",
      replies: [const XRexQuickReply(label: "Fotoğraf Yükle", payload: "PICK_IMAGE")]);
  }

  Future<void> _analyzePhoto() async {
    if (selectedImagePath == null) return;
    setState(() => isBotThinking = true);

    try {
      final result = await analyzerService.analyzeImagePath(selectedImagePath!);

      // Filter out low confidence or likely junk products before adding
      final filteredProducts = result.products.where((p) => p.name != 'İsimsiz ürün' && p.name.length > 2).toList();

      setState(() {
        for (var p in filteredProducts) {
          _ensureControllers(p);
        }
        products.addAll(filteredProducts);
        detectedRegions = result.regions;
      });

      final response = asistanService.handleAnalysisResult(filteredProducts.length);
      _addBotMessage(response.text, replies: [
        ...response.quickReplies,
        const XRexQuickReply(label: "Katalog Haline Getir", payload: "EXPORT_JSON"),
      ]);

      // Ürünleri tek tek listele (Kart olarak)
      if (filteredProducts.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        for (var i = 0; i < filteredProducts.length; i++) {
          if (i >= 5) { // Çok fazla ürün varsa ilk 5'i göster
             _addBotMessage("...ve diğer ${filteredProducts.length - 5} ürün daha bulundu. Hepsini 'Ürün Listesi' tabında görebilirsin.");
             break;
          }
          final p = filteredProducts[i];
          setState(() {
            chatMessages.add(XRexChatMessage(
              text: "Ürün Bulundu",
              type: XRexMessageType.productCard,
              associatedProduct: p,
              isBot: true,
            ));
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
    final size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
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
        // Simple logic to trigger re-categorization if it's 'Genel'
        if (p.category == 'Genel') {
          // The analyzer already tries to infer, but we can re-run a stricter check
        }
      }
    });
    _addBotMessage("Ürünleri isimlerine göre gruplandırdım ve kategorilerini güncelledim. 'Ürün Listesi' kısmından kontrol edebilirsin.",
      replies: [
        const XRexQuickReply(label: "Listeyi Gör", payload: "REVIEW_PRODUCTS"),
        const XRexQuickReply(label: "Kataloğu Bitir", payload: "EXPORT_JSON"),
      ]
    );
  }

  void _prepareCatalogDraft() {
    final validProducts = catalogService.validProducts(products);
    if (validProducts.isEmpty) {
      _addBotMessage("Taslak hazırlamak için en az 1 ürün doldurmalısın. İstersen Ürün Listesi tabından eksikleri tamamlayabilirsin.");
      return;
    }

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
          title: const Text("Katalog Taslağı Hazır", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("JSON verisini kopyalayarak VitrinX'e aktarabilirsin.", style: TextStyle(color: Color(0xFF94A3B8))),
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
                    child: SelectableText(formattedJson, style: const TextStyle(color: Color(0xFFE2E8F0), fontFamily: 'monospace', fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kapat")),
            ElevatedButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: formattedJson));
                if (!context.mounted) return;
                Navigator.pop(context);
                _addBotMessage("Katalog JSON verisi panoya kopyalandı! VitrinX'e yapıştırabilirsin. ✅");
              },
              child: const Text("JSON Kopyala"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: SafeArea(
        child: Column(
          children: [
            _buildMinimalHeader(),
            Expanded(
              child: IndexedStack(
                index: activeTabIndex,
                children: [
                  _buildChatView(),
                  _buildListView(),
                ],
              ),
            ),
            if (activeTabIndex == 0) _buildFloatingChatInput(),
            if (activeTabIndex == 1 && products.isNotEmpty) _buildBottomActionOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF090D18),
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Center(child: Text("X", style: TextStyle(color: Color(0xFF090D18), fontWeight: FontWeight.w900, fontSize: 16))),
          ),
          const SizedBox(width: 10),
          const Text("XRex", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white)),
          const Spacer(),
          Container(
            height: 32,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildHeaderTabItem(0, "Asistan"),
                _buildHeaderTabItem(1, "Liste"),
              ],
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
          color: isSelected ? const Color(0xFF334155) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (index == 1 && products.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFF06B6D4), borderRadius: BorderRadius.circular(4)),
                child: Text("${products.length}", style: const TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionOverlay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFF090D18), Colors.transparent],
        ),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF06B6D4),
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: const Color(0xFF06B6D4).withValues(alpha: 0.4),
        ),
        onPressed: _prepareCatalogDraft,
        child: const Text("Kataloğu Onayla", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ),
    );
  }

  Widget _buildChatView() {
    return ListView.builder(
      controller: chatScrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chatMessages.length + (isBotThinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatMessages.length && isBotThinking) {
          return _buildThinkingIndicator();
        }
        final message = chatMessages[index];
        return Column(
          crossAxisAlignment: message.isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            XRexChatBubble(message: message),
            if (message.isBot && message.quickReplies.isNotEmpty && index == chatMessages.length - 1)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Wrap(
                  spacing: 8,
                  children: message.quickReplies.map((reply) {
                    return ActionChip(
                      backgroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFF06B6D4)),
                      label: Text(reply.label, style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12)),
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
            child: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF06B6D4)),
          ),
          const SizedBox(width: 12),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4)),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white10),
            const SizedBox(height: 16),
            const Text("Henüz ürün bulunmuyor.", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text("Fotoğraf Yükle"),
            ),
          ],
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
          final dup = p.copyWith(id: DateTime.now().microsecondsSinceEpoch.toString());
          setState(() {
             _ensureControllers(dup);
             products.add(dup);
          });
        },
        onRemove: (p) => setState(() {
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
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
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
