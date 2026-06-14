import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/xrex_catalog_session.dart';
import '../models/xrex_draft_product.dart';
import '../models/xrex_parsed_product.dart';
import '../models/xrex_text_candidate.dart';
import '../screens/xrex_review_screen.dart';
import '../services/xrex_ocr_service.dart';
import '../services/xrex_text_parser_service.dart';
import '../widgets/xrex_text_candidate_panel.dart';
import '../widgets/xrex_draft_product_card.dart';

class XRexImportScreen extends StatefulWidget {
  final XRexCatalogSession session;

  const XRexImportScreen({super.key, required this.session});

  @override
  State<XRexImportScreen> createState() => _XRexImportScreenState();
}

class _XRexImportScreenState extends State<XRexImportScreen> {
  final List<XRexDraftProduct> products = [];
  final Map<String, TextEditingController> nameControllers = {};
  final Map<String, TextEditingController> priceControllers = {};
  final Map<String, TextEditingController> descriptionControllers = {};
  final Map<String, FocusNode> nameFocusNodes = {};
  final Map<String, FocusNode> priceFocusNodes = {};
  final Map<String, FocusNode> descriptionFocusNodes = {};
  final TextEditingController candidateTextController = TextEditingController();
  final XRexOcrService ocrService = const XRexOcrService();
  final XRexTextParserService textParserService = const XRexTextParserService();
  List<XRexTextCandidate> textCandidates = [];
  String? activeDraftId;
  bool isReadingImageText = false;

  String lastCategory = 'Genel';

  bool get _canUseOcr {
    final imagePath = widget.session.selectedImagePath;
    return !kIsWeb &&
        !isReadingImageText &&
        imagePath != null &&
        imagePath.trim().isNotEmpty;
  }

  String get _ocrButtonLabel {
    if (kIsWeb) return 'OCR Android testinde çalışır';
    return 'Fotoğraftan metni oku';
  }

  String? get _ocrHelpText {
    if (kIsWeb) {
      return 'Chrome/web ekranında OCR desteklenmez. Webde metni elle yapıştırıp taslak oluşturabilirsiniz.';
    }
    if (!_canUseOcr && !isReadingImageText) {
      return 'OCR için Android cihazda dosya yolu olan bir fotoğraf seçilmelidir.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _addDraft();
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

  void _removeDraft(String id) {
    products.removeWhere((product) => product.id == id);
    _disposeControllers(id);
    if (activeDraftId == id) {
      activeDraftId = products.isEmpty ? null : products.first.id;
    }
    setState(() {});
  }

  void _parseCandidateText(String value) {
    setState(() {
      textCandidates = textParserService.parse(value);
    });
  }

  Future<void> _readImageText() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR webde desteklenmez. Android testinde çalışır.'),
        ),
      );
      return;
    }

    final imagePath = widget.session.selectedImagePath;
    if (imagePath == null || imagePath.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR için fotoğraf dosya yolu bulunamadı.'),
        ),
      );
      return;
    }

    setState(() => isReadingImageText = true);
    try {
      final text = await ocrService.readTextFromImagePath(imagePath);
      if (!mounted) return;
      if (text.isEmpty) {
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
      if (mounted) {
        setState(() => isReadingImageText = false);
      }
    }
  }

  void _applyCandidateToActiveDraft(XRexTextCandidate candidate) {
    if (products.isEmpty) return;

    final target = products.firstWhere(
      (product) => product.id == activeDraftId,
      orElse: () => products.first,
    );

    if (candidate.type == XRexTextCandidateType.price) {
      target.price = candidate.value;
      priceControllers[target.id]?.text = candidate.value;
    } else {
      if (target.name.trim().isEmpty) {
        target.name = candidate.value;
        nameControllers[target.id]?.text = candidate.value;
      } else {
        target.description = candidate.value;
        descriptionControllers[target.id]?.text = candidate.value;
      }
    }

    setState(() {});
  }

  void _buildDraftsFromCandidateText() {
    final parsedProducts = textParserService.parseProducts(
      candidateTextController.text,
    );

    if (parsedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ürün taslağına dönüşecek fiyatlı satır bulunamadı.'),
        ),
      );
      return;
    }

    var targetIndex = 0;
    while (targetIndex < products.length && !products[targetIndex].isBlank) {
      targetIndex += 1;
    }

    for (final parsed in parsedProducts) {
      if (targetIndex < products.length) {
        _fillDraft(products[targetIndex], parsed);
        targetIndex += 1;
        continue;
      }

      final draft = XRexDraftProduct(id: _newId(), category: lastCategory);
      products.add(draft);
      _ensureControllers(draft);
      _fillDraft(draft, parsed);
      targetIndex += 1;
    }

    activeDraftId = products.isEmpty ? null : products.last.id;
    setState(() {});
  }

  void _fillDraft(XRexDraftProduct draft, XRexParsedProduct parsed) {
    draft.name = parsed.name;
    draft.price = parsed.price;
    draft.description = parsed.description;
    draft.category = lastCategory;
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
    nameFocusNodes.putIfAbsent(product.id, FocusNode.new);
    priceFocusNodes.putIfAbsent(product.id, FocusNode.new);
    descriptionFocusNodes.putIfAbsent(product.id, FocusNode.new);
  }

  void _disposeControllers(String id) {
    nameControllers.remove(id)?.dispose();
    priceControllers.remove(id)?.dispose();
    descriptionControllers.remove(id)?.dispose();
    nameFocusNodes.remove(id)?.dispose();
    priceFocusNodes.remove(id)?.dispose();
    descriptionFocusNodes.remove(id)?.dispose();
  }

  void _goReview() {
    final validProducts =
        products.where((product) => !product.isBlank).toList();
    if (validProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önizleme için en az 1 ürün doldurun.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => XRexReviewScreen(
              session: widget.session.copyWith(
                products: validProducts,
                ocrRawText: candidateTextController.text,
              ),
            ),
      ),
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('X-rex Taslak Paneli'),
        actions: [
          TextButton.icon(
            onPressed: _goReview,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(
              'Son kontrol (${products.where((p) => !p.isBlank).length})',
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;
            return Padding(
              padding: const EdgeInsets.all(16),
              child:
                  isWide
                      ? Row(
                        children: [
                          SizedBox(
                            width: 460,
                            child: _ReferenceColumn(
                              bytes: widget.session.selectedImageBytes,
                              textController: candidateTextController,
                              candidates: textCandidates,
                              hasDraft: products.isNotEmpty,
                              canBuildDrafts:
                                  candidateTextController.text
                                      .trim()
                                      .isNotEmpty,
                              onTextChanged: _parseCandidateText,
                              onReadImageText: _readImageText,
                              onBuildDrafts: _buildDraftsFromCandidateText,
                              onApplyToActiveDraft:
                                  _applyCandidateToActiveDraft,
                              canReadImageText: _canUseOcr,
                              isReadingImageText: isReadingImageText,
                              ocrButtonLabel: _ocrButtonLabel,
                              ocrHelpText: _ocrHelpText,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: _draftList()),
                        ],
                      )
                      : Column(
                        children: [
                          SizedBox(
                            height: 260,
                            child: _ReferenceImage(
                              bytes: widget.session.selectedImageBytes,
                            ),
                          ),
                          const SizedBox(height: 14),
                          XRexTextCandidatePanel(
                            textController: candidateTextController,
                            candidates: textCandidates,
                            hasDraft: products.isNotEmpty,
                            canBuildDrafts:
                                candidateTextController.text.trim().isNotEmpty,
                            onTextChanged: _parseCandidateText,
                            onReadImageText: _readImageText,
                            onBuildDrafts: _buildDraftsFromCandidateText,
                            onApplyToActiveDraft: _applyCandidateToActiveDraft,
                            canReadImageText: _canUseOcr,
                            isReadingImageText: isReadingImageText,
                            ocrButtonLabel: _ocrButtonLabel,
                            ocrHelpText: _ocrHelpText,
                          ),
                          const SizedBox(height: 14),
                          Expanded(child: _draftList()),
                        ],
                      ),
            );
          },
        ),
      ),
    );
  }

  Widget _draftList() {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              _ensureControllers(product);
              return XRexDraftProductCard(
                index: index + 1,
                product: product,
                nameController: nameControllers[product.id]!,
                priceController: priceControllers[product.id]!,
                descriptionController: descriptionControllers[product.id]!,
                nameFocusNode: nameFocusNodes[product.id]!,
                priceFocusNode: priceFocusNodes[product.id]!,
                descriptionFocusNode: descriptionFocusNodes[product.id]!,
                onChanged: (changed) {
                  lastCategory = changed.category;
                  activeDraftId = changed.id;
                },
                onDuplicate: () => _addDraft(source: product),
                onRemove: () => _removeDraft(product.id),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addDraft,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ürün taslağı ekle'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _goReview,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Kataloğa aktar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A00),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

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
    for (final node in nameFocusNodes.values) {
      node.dispose();
    }
    for (final node in priceFocusNodes.values) {
      node.dispose();
    }
    for (final node in descriptionFocusNodes.values) {
      node.dispose();
    }
    candidateTextController.dispose();
    super.dispose();
  }
}

class _ReferenceColumn extends StatelessWidget {
  final Uint8List? bytes;
  final TextEditingController textController;
  final List<XRexTextCandidate> candidates;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<XRexTextCandidate> onApplyToActiveDraft;
  final VoidCallback onBuildDrafts;
  final VoidCallback onReadImageText;
  final bool hasDraft;
  final bool canBuildDrafts;
  final bool canReadImageText;
  final bool isReadingImageText;
  final String ocrButtonLabel;
  final String? ocrHelpText;

  const _ReferenceColumn({
    required this.bytes,
    required this.textController,
    required this.candidates,
    required this.onTextChanged,
    required this.onApplyToActiveDraft,
    required this.onBuildDrafts,
    required this.onReadImageText,
    required this.hasDraft,
    required this.canBuildDrafts,
    required this.canReadImageText,
    required this.isReadingImageText,
    required this.ocrButtonLabel,
    required this.ocrHelpText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _ReferenceImage(bytes: bytes)),
        const SizedBox(height: 12),
        XRexTextCandidatePanel(
          textController: textController,
          candidates: candidates,
          hasDraft: hasDraft,
          canBuildDrafts: canBuildDrafts,
          canReadImageText: canReadImageText,
          isReadingImageText: isReadingImageText,
          ocrButtonLabel: ocrButtonLabel,
          ocrHelpText: ocrHelpText,
          onTextChanged: onTextChanged,
          onReadImageText: onReadImageText,
          onBuildDrafts: onBuildDrafts,
          onApplyToActiveDraft: onApplyToActiveDraft,
        ),
      ],
    );
  }
}

class _ReferenceImage extends StatelessWidget {
  final Uint8List? bytes;

  const _ReferenceImage({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1728),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF233149)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.zoom_in_rounded, size: 18, color: Color(0xFF06B6D4)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Referans fotoğrafı yakınlaştırabilirsiniz.',
                    style: TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  maxScale: 5,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child:
                        bytes == null
                            ? const Icon(Icons.broken_image_outlined, size: 48)
                            : Image.memory(
                              bytes!,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              fit: BoxFit.contain,
                              alignment: Alignment.topCenter,
                              errorBuilder: (_, __, ___) {
                                return const Icon(
                                  Icons.broken_image_outlined,
                                  size: 48,
                                );
                              },
                            ),
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
