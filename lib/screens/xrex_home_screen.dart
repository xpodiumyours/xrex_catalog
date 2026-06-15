import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/xrex_catalog_session.dart';
import '../models/xrex_detected_region.dart';
import '../models/xrex_draft_product.dart';
import '../models/xrex_parsed_product.dart';
import '../models/xrex_text_candidate.dart';
import '../services/xrex_catalog_analyzer_service.dart';
import '../services/xrex_catalog_service.dart';
import '../services/xrex_ocr_service.dart';
import '../services/xrex_text_parser_service.dart';
import '../widgets/xrex_glass_panel.dart';
import '../widgets/xrex_product_table.dart';
import '../widgets/xrex_text_candidate_panel.dart';

class XRexHomeScreen extends StatefulWidget {
  const XRexHomeScreen({super.key});

  @override
  State<XRexHomeScreen> createState() => _XRexHomeScreenState();
}

class _XRexHomeScreenState extends State<XRexHomeScreen> {
  static const String pendingBusinessType = 'Fotoğraf/metin bekleniyor';

  static const Map<String, List<String>> sectorKeywords = {
    'Gözlükçü': ['gözlük', 'gozluk', 'lens', 'rayban', 'osse', 'optik'],
    'Butik': ['elbise', 'pijama', 'çorap', 'corap', 'beden', 'giyim'],
    'Aktar': ['baharat', 'kekik', 'adaçayı', 'adacayi', 'bitki', 'yağı'],
    'Nalbur': ['vida', 'matkap', 'çekiç', 'cekic', 'anahtar', 'hırdavat'],
    'Kozmetikçi': ['krem', 'ruj', 'parfüm', 'parfum', 'şampuan', 'makyaj'],
    'Kırtasiye': ['defter', 'kalem', 'silgi', 'dosya', 'kitap'],
    'Oyuncakçı': ['oyuncak', 'lego', 'bebek', 'araba', 'puzzle'],
    'Manav': ['elma', 'domates', 'biber', 'meyve', 'sebze'],
  };

  final List<XRexDraftProduct> products = [];
  final Map<String, TextEditingController> nameControllers = {};
  final Map<String, TextEditingController> priceControllers = {};
  final Map<String, TextEditingController> descriptionControllers = {};
  final TextEditingController candidateTextController = TextEditingController();
  final XRexOcrService ocrService = const XRexOcrService();
  final XRexTextParserService textParserService = const XRexTextParserService();
  final XRexCatalogService catalogService = const XRexCatalogService();
  final XRexCatalogAnalyzerService analyzerService =
      const XRexCatalogAnalyzerService();

  String selectedBusinessType = pendingBusinessType;
  Uint8List? selectedImageBytes;
  String? selectedImagePath;
  Size? selectedImageSize;
  List<XRexDetectedRegion> detectedRegions = [];
  List<XRexTextCandidate> textCandidates = [];
  String? activeDraftId;
  String? autoCatalogMessage;
  String? visualAnalysisMessage;
  bool isPicking = false;
  bool isReadingImageText = false;
  bool isAnalyzingPhoto = false;
  bool isAutoCatalogError = false;
  bool isVisualAnalysisError = false;
  bool isTableView = false;
  String lastCategory = 'Genel';

  bool get hasImage => selectedImageBytes != null;

  bool get hasDetectedSector => selectedBusinessType != pendingBusinessType;

  String get detectedSectorLabel =>
      hasDetectedSector ? selectedBusinessType : 'Ürünlerden tahmin edilecek';

  String get detectedSectorNote {
    if (!hasImage) return 'Fotoğraf yüklenince analiz alanı burada açılır.';
    if (!hasDetectedSector) {
      return 'Ürün adı, fiyat veya etiket metni girilince sektör tahmini oluşur.';
    }
    return 'Tahmin yerel olarak üretildi; ürün kartlarında kategori düzenlenebilir.';
  }

  bool get _isMobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  bool get _canUseOcr {
    return _isMobile &&
        !isReadingImageText &&
        selectedImagePath != null &&
        selectedImagePath!.trim().isNotEmpty;
  }

  String? get _ocrHelpText {
    if (!_isMobile) {
      return 'Bu platformda metni elle yapıştırabilirsiniz. Android/iOS cihazlarda görselden metin okuma çalışır.';
    }
    if (!_canUseOcr && !isReadingImageText) {
      return 'Görselden metin okuma için cihazda fotoğraf seçilmelidir.';
    }
    return null;
  }

  int get validProductCount =>
      products.where((product) => !product.isBlank).length;

  int get warningCount {
    return products.where((product) {
      if (product.isBlank) return false;
      return _productWarnings(product).isNotEmpty;
    }).length;
  }

  int get readyCount =>
      (validProductCount - warningCount).clamp(0, validProductCount);

  Future<void> _pickImage() async {
    if (isPicking) return;
    setState(() => isPicking = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      final bytes = result?.files.single.bytes;
      if (!mounted) return;
      if (bytes == null) {
        setState(() => isPicking = false);
        return;
      }

      final imageSize = await _decodeImageSize(bytes);
      if (!mounted) return;

      setState(() {
        selectedImageBytes = bytes;
        selectedImagePath = kIsWeb ? null : result?.files.single.path;
        selectedImageSize = imageSize;
        detectedRegions = [];
        visualAnalysisMessage = null;
        isVisualAnalysisError = false;
        isPicking = false;
        if (products.isEmpty) _addDraft();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => isPicking = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf seçilemedi: $error')));
    }
  }

  void _resetImage() {
    setState(() {
      selectedImageBytes = null;
      selectedImagePath = null;
      selectedImageSize = null;
      detectedRegions = [];
      products.clear();
      textCandidates = [];
      candidateTextController.clear();
      autoCatalogMessage = null;
      visualAnalysisMessage = null;
      isAutoCatalogError = false;
      isVisualAnalysisError = false;
      activeDraftId = null;
      selectedBusinessType = pendingBusinessType;
      lastCategory = 'Genel';
    });

    for (final id in [...nameControllers.keys]) {
      _disposeControllers(id);
    }
  }

  Future<Size?> _decodeImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  void _addDraft({XRexDraftProduct? source}) {
    final draft =
        source?.copyWith(id: _newId()) ??
        XRexDraftProduct(id: _newId(), category: lastCategory);

    products.add(draft);
    _ensureControllers(draft);
    activeDraftId = draft.id;
    setState(() {});
  }

  void _removeDraft(XRexDraftProduct product) {
    products.removeWhere((item) => item.id == product.id);
    _disposeControllers(product.id);
    activeDraftId = products.isEmpty ? null : products.first.id;
    setState(() {});
  }

  void _parseCandidateText(String value) {
    final detectedSector = _detectSectorFromText(value);
    setState(() {
      textCandidates = textParserService.parse(value);
      _applyDetectedSector(detectedSector);
      autoCatalogMessage = null;
      isAutoCatalogError = false;
    });
  }

  Future<void> _readImageText() async {
    if (!_canUseOcr || selectedImagePath == null) return;

    setState(() => isReadingImageText = true);
    try {
      final text = await ocrService.readTextFromImagePath(selectedImagePath!);
      if (!mounted) return;
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotoğrafta okunabilir metin bulunamadı.'),
          ),
        );
        return;
      }

      candidateTextController.text = text;
      _parseCandidateText(text);
      _buildDraftsFromCandidateText();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('OCR okuma hatası: $error')));
    } finally {
      if (mounted) setState(() => isReadingImageText = false);
    }
  }

  Future<void> _analyzePhoto() async {
    if (isAnalyzingPhoto) return;

    if (!_isMobile) {
      setState(() {
        visualAnalysisMessage =
            'Görselden ürün tespiti bu platformda desteklenmiyor. Metni elle yapıştırarak taslak oluşturabilirsiniz.';
        isVisualAnalysisError = true;
      });
      return;
    }

    final imagePath = selectedImagePath;
    if (!hasImage || imagePath == null || imagePath.trim().isEmpty) {
      setState(() {
        visualAnalysisMessage =
            'Analiz için Android cihazda dosya yolu olan bir fotoğraf seçin.';
        isVisualAnalysisError = true;
      });
      return;
    }

    setState(() {
      isAnalyzingPhoto = true;
      visualAnalysisMessage = 'Fotoğraf analiz ediliyor...';
      isVisualAnalysisError = false;
    });

    try {
      final result = await analyzerService.analyzeImagePath(imagePath);
      if (!mounted) return;

      setState(() {
        detectedRegions = result.regions;
        candidateTextController.text = result.rawText;
        textCandidates = textParserService.parse(result.rawText);
        _applyDetectedSector(_detectSectorFromText(result.rawText));

        if (result.products.isNotEmpty) {
          if (validProductCount == 0) {
            _clearProducts();
          }

          for (final product in result.products) {
            final category = _categoryForBusinessType(selectedBusinessType);
            final draft = product.copyWith(
              id: _newId(),
              category: category == 'Genel' ? product.category : category,
            );
            products.add(draft);
            _ensureControllers(draft);
          }
          activeDraftId = products.isEmpty ? null : products.last.id;
        }

        final productCount = result.products.length;
        final regionCount = result.regions.length;
        visualAnalysisMessage =
            productCount == 0 && regionCount == 0
                ? 'Fotoğrafta ürün kutusu veya okunabilir ürün metni bulunamadı.'
                : '$regionCount ürün bölgesi tespit edildi, $productCount katalog taslağı oluşturuldu.';
        isVisualAnalysisError = productCount == 0 && regionCount == 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        visualAnalysisMessage = 'Görsel analizi tamamlanamadı: $error';
        isVisualAnalysisError = true;
      });
    } finally {
      if (mounted) setState(() => isAnalyzingPhoto = false);
    }
  }

  void _applyCandidateToActiveDraft(XRexTextCandidate candidate) {
    if (products.isEmpty) _addDraft();

    final target = products.firstWhere(
      (product) => product.id == activeDraftId,
      orElse: () => products.first,
    );

    if (candidate.type == XRexTextCandidateType.price) {
      target.price = candidate.value;
      priceControllers[target.id]?.text = candidate.value;
    } else if (target.name.trim().isEmpty) {
      target.name = candidate.value;
      nameControllers[target.id]?.text = candidate.value;
    } else {
      target.description = candidate.value;
      descriptionControllers[target.id]?.text = candidate.value;
    }

    setState(() {});
  }

  void _buildDraftsFromCandidateText() {
    final parsedProducts = textParserService.parseProducts(
      candidateTextController.text,
    );

    if (parsedProducts.isEmpty) {
      setState(() {
        autoCatalogMessage = 'Fiyat içeren ürün satırı bulunamadı.';
        isAutoCatalogError = true;
      });
      return;
    }

    var targetIndex = 0;
    var createdCount = 0;

    for (final parsed in parsedProducts) {
      while (targetIndex < products.length && !products[targetIndex].isBlank) {
        targetIndex += 1;
      }

      if (targetIndex < products.length) {
        _fillDraft(products[targetIndex], parsed);
      } else {
        final draft = XRexDraftProduct(id: _newId(), category: lastCategory);
        products.add(draft);
        _ensureControllers(draft);
        _fillDraft(draft, parsed);
      }
      targetIndex += 1;
      createdCount += 1;
    }

    activeDraftId = products.isEmpty ? null : products.last.id;
    setState(() {
      autoCatalogMessage = '$createdCount ürün taslağı oluşturuldu.';
      isAutoCatalogError = false;
    });
  }

  void _fillDraft(XRexDraftProduct draft, XRexParsedProduct parsed) {
    draft.name = parsed.name;
    draft.price = parsed.price;
    draft.description = parsed.description;
    draft.category = _categoryForBusinessType(selectedBusinessType);
    draft.stockStatus = 'Mevcut';

    nameControllers[draft.id]?.text = draft.name;
    priceControllers[draft.id]?.text = draft.price;
    descriptionControllers[draft.id]?.text = draft.description;
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

  void _disposeControllers(String id) {
    nameControllers.remove(id)?.dispose();
    priceControllers.remove(id)?.dispose();
    descriptionControllers.remove(id)?.dispose();
  }

  void _clearProducts() {
    for (final id in [...nameControllers.keys]) {
      _disposeControllers(id);
    }
    products.clear();
    activeDraftId = null;
  }

  String? _detectSectorFromText(String text) {
    final normalized = text.toLowerCase();
    var bestSector = '';
    var bestScore = 0;

    for (final entry in sectorKeywords.entries) {
      var score = 0;
      for (final keyword in entry.value) {
        if (normalized.contains(keyword.toLowerCase())) score += 1;
      }
      if (score > bestScore) {
        bestSector = entry.key;
        bestScore = score;
      }
    }

    return bestScore == 0 ? null : bestSector;
  }

  void _applyDetectedSector(String? sector) {
    if (sector == null) return;
    selectedBusinessType = sector;
    lastCategory = _categoryForBusinessType(sector);
  }

  void _refreshSectorFromProducts() {
    final productText = products
        .map((product) => '${product.name} ${product.description}')
        .join(' ');
    _applyDetectedSector(_detectSectorFromText(productText));
  }

  String _categoryForBusinessType(String businessType) {
    return switch (businessType) {
      'Gözlükçü' => 'Gözlük',
      'Butik' => 'Giyim',
      'Aktar' => 'Aktar ürünleri',
      'Nalbur' => 'Hırdavat',
      'Kozmetikçi' => 'Kozmetik',
      'Kırtasiye' => 'Kırtasiye',
      'Oyuncakçı' => 'Oyuncak',
      'Manav' => 'Manav',
      _ => 'Genel',
    };
  }

  void _prepareCatalogDraft() {
    final validProducts = catalogService.validProducts(products);
    if (validProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Taslak hazırlamak için en az 1 ürün doldurun.'),
        ),
      );
      return;
    }

    final session = XRexCatalogSession(
      sessionId: DateTime.now().microsecondsSinceEpoch.toString(),
      businessType: hasDetectedSector ? selectedBusinessType : 'Belirlenmedi',
      selectedImageBytes: selectedImageBytes,
      selectedImagePath: selectedImagePath,
      ocrRawText: candidateTextController.text,
      products: validProducts,
    );
    final formattedJson = catalogService.formattedJson(session);

    final hasReadyProducts = validProducts.any((p) =>
        p.name.isNotEmpty &&
        p.price.isNotEmpty &&
        RegExp(r'\d').hasMatch(p.price));
    final dialogTitle = hasReadyProducts ? 'Katalog taslağı hazır' : 'Envanter & Blog Taslağı hazır';
    final dialogSubText = hasReadyProducts
        ? 'Ürün kataloğu taslağı oluşturuldu. Teknik çıktı olarak JSON verisini kopyalayabilirsiniz.'
        : 'Net fiyat çıkarılamadığı için Görsel Envanter ve yerel Blog Taslağı oluşturuldu. JSON verisini kopyalayabilirsiniz.';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text(
            dialogTitle,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  dialogSubText,
                  style: const TextStyle(color: Color(0xFF94A3B8)),
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
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: formattedJson));
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(hasReadyProducts
                        ? 'Katalog JSON verisi panoya kopyalandı.'
                        : 'Envanter & Blog Taslağı JSON verisi panoya kopyalandı.'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('JSON kopyala'),
            ),
          ],
        );
      },
    );
  }

  List<String> _productWarnings(XRexDraftProduct product) {
    final warnings = <String>[];
    if (product.name.trim().isEmpty) warnings.add('Ürün adı eksik');
    if (product.price.trim().isEmpty) {
      warnings.add('Fiyat eksik');
    } else if (!RegExp(r'\d{1,9}(?:[.,]\d{1,2})?').hasMatch(product.price)) {
      warnings.add('Fiyat kontrol edilmeli');
    }
    return warnings;
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void dispose() {
    for (final controller in nameControllers.values) {
      controller.dispose();
    }
    for (final controller in priceControllers.values) {
      controller.dispose();
    }
    for (final controller in descriptionControllers.values) {
      controller.dispose();
    }
    candidateTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showMobileAction =
        hasImage && MediaQuery.sizeOf(context).width < 1060;

    return Scaffold(
      bottomNavigationBar:
          showMobileAction
              ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildBottomAction(),
              )
              : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.35,
            colors: [Color(0xFF10213A), Color(0xFF050711)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildWorkspace(),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1060;

        if (!isWide) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 92),
            children: [
              _buildMobileTopBar(),
              const SizedBox(height: 12),
              SizedBox(
                height: hasImage ? 220 : 320,
                child: _buildPhotoPanel(compact: true),
              ),
              const SizedBox(height: 14),
              _buildSectorInsightCard(compact: true),
              const SizedBox(height: 14),
              _buildMobileParserPanel(),
              const SizedBox(height: 14),
              _buildMobileSummaryStrip(),
              const SizedBox(height: 14),
              SizedBox(
                height: 560,
                child: _buildProductPanel(forceCards: true),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 31, child: _buildPhotoPanel()),
                  const SizedBox(width: 14),
                  Expanded(flex: 43, child: _buildProductPanel()),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 26,
                    child: Column(
                      children: [
                        _buildSectorInsightCard(),
                        const SizedBox(height: 14),
                        Expanded(child: _buildParserPanel()),
                        const SizedBox(height: 14),
                        _buildSummaryPanel(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildBottomAction(),
          ],
        );
      },
    );
  }

  Widget _buildSectorInsightCard({bool compact = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: const Color(0xE60B1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              hasDetectedSector
                  ? const Color(0x5522C55E)
                  : const Color(0x3322D3EE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  hasDetectedSector
                      ? const Color(0xFF052E1B)
                      : const Color(0xFF062D3B),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color:
                    hasDetectedSector
                        ? const Color(0x6622C55E)
                        : const Color(0x6606B6D4),
              ),
            ),
            child: Icon(
              hasDetectedSector
                  ? Icons.auto_awesome_rounded
                  : Icons.manage_search_rounded,
              color:
                  hasDetectedSector
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF22D3EE),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sektör tahmini',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detectedSectorLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  Text(
                    detectedSectorNote,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTopBar() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFF04111D),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'X-rex',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '$detectedSectorLabel · ${products.length} taslak',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Fotoğrafı değiştir',
          onPressed: _resetImage,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildMobileSummaryStrip() {
    return Row(
      children: [
        Expanded(
          child: _buildMiniMetric(
            label: 'Ürün',
            value: '${products.length}',
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF67E8F9),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniMetric(
            label: 'İncele',
            value: '$warningCount',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFFF8A00),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniMetric(
            label: 'Hazır',
            value: '$readyCount',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF22C55E),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xE60B1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileParserPanel() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0x3322D3EE)),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0x3322D3EE)),
      ),
      backgroundColor: const Color(0x99111A2D),
      collapsedBackgroundColor: const Color(0x99111A2D),
      leading: const Icon(
        Icons.auto_fix_high_rounded,
        color: Color(0xFF22D3EE),
      ),
      title: const Text(
        'Metinden hızlı ürün oluştur',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
      subtitle: const Text(
        'İstersen etiket metnini buraya yapıştır.',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _buildParserPanel(),
        ),
      ],
    );
  }

  Widget _buildPhotoPanel({bool compact = false}) {
    final imageBytes = selectedImageBytes;

    return XRexGlassPanel(
      padding: EdgeInsets.zero,
      strongGlow: true,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(compact ? 10 : 14),
            child: Row(
              children: [
                const Icon(
                  Icons.photo_camera_outlined,
                  color: Color(0xFF22D3EE),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    imageBytes == null ? 'Ürün fotoğrafı' : 'Yüklenen fotoğraf',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (imageBytes != null && !compact)
                  IconButton(
                    tooltip: 'Fotoğrafı değiştir',
                    onPressed: _resetImage,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                if (imageBytes != null)
                  TextButton.icon(
                    onPressed: isAnalyzingPhoto ? null : _analyzePhoto,
                    icon:
                        isAnalyzingPhoto
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.center_focus_strong_rounded),
                    label: Text(compact ? 'Analiz' : 'Ürünleri analiz et'),
                  ),
              ],
            ),
          ),
          Expanded(
            child:
                imageBytes == null
                    ? _buildPhotoEmptyState(compact: compact)
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        return InteractiveViewer(
                          maxScale: 5,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.memory(
                                    imageBytes,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.center,
                                  ),
                                ),
                                if (selectedImageSize != null)
                                  Positioned.fill(
                                    child: _DetectedRegionOverlay(
                                      imageSize: selectedImageSize!,
                                      regions: detectedRegions,
                                      products: products,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          if (visualAnalysisMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _InlineStatus(
                message: visualAnalysisMessage!,
                isError: isVisualAnalysisError,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoEmptyState({required bool compact}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, compact ? 16 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: compact ? 52 : 64,
              height: compact ? 52 : 64,
              decoration: BoxDecoration(
                color: const Color(0xFF062D3B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x6606B6D4)),
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                color: Color(0xFF22D3EE),
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Fotoğraf yükle ve ürün listesini burada oluşturmaya başla.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mağaza, vitrin, tezgah veya ekran görüntüsü kullanabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: isPicking ? null : _pickImage,
              icon:
                  isPicking
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.photo_camera_back_rounded),
              label: const Text('Fotoğraf yükle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: const Color(0xFF04111D),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductPanel({bool forceCards = false}) {
    final useTableView = forceCards ? false : isTableView;

    return XRexGlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Color(0xFF06B6D4)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tespit edilen ürünler',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!forceCards) ...[
                IconButton(
                  tooltip: 'Tablo görünümü',
                  onPressed: () => setState(() => isTableView = true),
                  icon: Icon(
                    Icons.table_rows_rounded,
                    color:
                        useTableView ? const Color(0xFF06B6D4) : Colors.white60,
                  ),
                ),
                IconButton(
                  tooltip: 'Kart görünümü',
                  onPressed: () => setState(() => isTableView = false),
                  icon: Icon(
                    Icons.grid_view_rounded,
                    color:
                        !useTableView
                            ? const Color(0xFF06B6D4)
                            : Colors.white60,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: XRexProductTable(
              products: products,
              isTableView: useTableView,
              nameControllers: nameControllers,
              priceControllers: priceControllers,
              descriptionControllers: descriptionControllers,
              onChanged: (product) {
                lastCategory = product.category;
                activeDraftId = product.id;
                _refreshSectorFromProducts();
                setState(() {});
              },
              onDuplicate: (product) => _addDraft(source: product),
              onRemove: _removeDraft,
              getWarnings: _productWarnings,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _addDraft,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ürün ekle'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF22D3EE),
              side: const BorderSide(color: Color(0xFF155E75)),
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParserPanel() {
    return XRexTextCandidatePanel(
      textController: candidateTextController,
      candidates: textCandidates,
      hasDraft: products.isNotEmpty,
      canBuildDrafts: candidateTextController.text.trim().isNotEmpty,
      onTextChanged: _parseCandidateText,
      onReadImageText: _readImageText,
      onBuildDrafts: _buildDraftsFromCandidateText,
      onApplyToActiveDraft: _applyCandidateToActiveDraft,
      canReadImageText: _canUseOcr,
      isReadingImageText: isReadingImageText,
      ocrButtonLabel: 'Görseldeki metni oku',
      showOcrButton: _isMobile,
      ocrHelpText: _ocrHelpText,
      autoCatalogMessage: autoCatalogMessage,
      isAutoCatalogError: isAutoCatalogError,
    );
  }

  Widget _buildSummaryPanel({bool isCompact = false}) {
    return XRexGlassPanel(
      padding: const EdgeInsets.all(18),
      strongGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const XRexSectionHeader(
            icon: Icons.analytics_outlined,
            eyebrow: 'ANALİZ',
            title: 'Analiz özeti',
          ),
          const SizedBox(height: 18),
          _buildSummaryRow(
            Icons.storefront_rounded,
            'Sektör tespiti',
            detectedSectorLabel,
          ),
          const Divider(color: Color(0xFF1F2A3D), height: 24),
          _buildSummaryRow(
            Icons.inventory_2_outlined,
            'Ürün sayısı',
            '${products.length}',
          ),
          const Divider(color: Color(0xFF1F2A3D), height: 24),
          _buildSummaryRow(
            Icons.warning_amber_rounded,
            'İncelenecek',
            '$warningCount',
            color: const Color(0xFFFF8A00),
          ),
          const Divider(color: Color(0xFF1F2A3D), height: 24),
          _buildSummaryRow(
            Icons.check_circle_outline_rounded,
            'Hazır',
            '$readyCount',
            color: const Color(0xFF22C55E),
          ),
          if (isCompact) ...[const SizedBox(height: 18), _buildBottomAction()],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    IconData icon,
    String label,
    String value, {
    Color color = Colors.white70,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    final hasReadyProducts = products.where((product) => !product.isBlank).any((p) =>
        p.name.isNotEmpty &&
        p.price.isNotEmpty &&
        RegExp(r'\d').hasMatch(p.price));
    final buttonLabel = hasReadyProducts
        ? 'Katalog taslağını hazırla'
        : 'Görsel Envanter & Blog Taslağı Hazırla';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: validProductCount == 0 ? null : _prepareCatalogDraft,
        icon: const Icon(Icons.fact_check_rounded),
        label: Text(buttonLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6A00),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF334155),
          disabledForegroundColor: const Color(0xFF94A3B8),
          padding: const EdgeInsets.symmetric(vertical: 18),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _DetectedRegionOverlay extends StatelessWidget {
  final Size imageSize;
  final List<XRexDetectedRegion> regions;
  final List<XRexDraftProduct> products;

  const _DetectedRegionOverlay({
    required this.imageSize,
    required this.regions,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    if (regions.isEmpty || imageSize.width <= 0 || imageSize.height <= 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = _containScale(
          source: imageSize,
          target: Size(constraints.maxWidth, constraints.maxHeight),
        );
        final displayWidth = imageSize.width * scale;
        final displayHeight = imageSize.height * scale;
        final offsetX = (constraints.maxWidth - displayWidth) / 2;
        final offsetY = (constraints.maxHeight - displayHeight) / 2;

        return Stack(
          children: List.generate(regions.length, (index) {
            final region = regions[index];
            final rect = region.boundingBox;

            final matchingProduct = products.firstWhere(
              (p) => p.detectionIds.contains(region.id) || p.detectionId == region.id,
              orElse: () => XRexDraftProduct(id: ''),
            );

            String displayLabel = '${index + 1}';
            if (matchingProduct.id.isNotEmpty && matchingProduct.sourceIndex != null) {
              displayLabel = matchingProduct.sourceIndex!.replaceAll('#', '');
            }

            return Positioned(
              left: offsetX + rect.left * scale,
              top: offsetY + rect.top * scale,
              width: rect.width * scale,
              height: rect.height * scale,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF22D3EE), width: 2),
                  color: const Color(0x3322D3EE),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF06B6D4),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      displayLabel,
                      style: const TextStyle(
                        color: Color(0xFF04111D),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _containScale({required Size source, required Size target}) {
    final widthScale = target.width / source.width;
    final heightScale = target.height / source.height;
    return widthScale < heightScale ? widthScale : heightScale;
  }
}

class _InlineStatus extends StatelessWidget {
  final String message;
  final bool isError;

  const _InlineStatus({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFFF8A00) : const Color(0xFF22D3EE);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? const Color(0xFFFED7AA) : color,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
