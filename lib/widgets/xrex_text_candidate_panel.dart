import 'package:flutter/material.dart';

import '../models/xrex_text_candidate.dart';
import 'xrex_glass_panel.dart';

class XRexTextCandidatePanel extends StatelessWidget {
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
  final bool showOcrButton;
  final String? ocrHelpText;
  final String? autoCatalogMessage;
  final bool isAutoCatalogError;

  const XRexTextCandidatePanel({
    super.key,
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
    this.showOcrButton = true,
    this.ocrHelpText,
    this.autoCatalogMessage,
    this.isAutoCatalogError = false,
  });

  @override
  Widget build(BuildContext context) {
    return XRexGlassPanel(
      padding: const EdgeInsets.all(16),
      accentColor: const Color(0xFF06B6D4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const XRexSectionHeader(
            icon: Icons.auto_awesome_motion_rounded,
            eyebrow: 'ÜRÜN OLUŞTURMA',
            title: 'Ürünleri birlikte çıkaralım',
            trailing: 'Yerel',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: textController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Ürün adı, fiyat veya etiket metnini buraya yapıştır',
              hintText: 'Örn: Penti çorap 175 TL\nParlak model',
            ),
            onChanged: onTextChanged,
          ),
          const SizedBox(height: 12),
          if (showOcrButton)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canReadImageText ? onReadImageText : null,
                icon:
                    isReadingImageText
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.document_scanner_outlined),
                label: Text(
                  isReadingImageText ? 'Fotoğraf okunuyor' : ocrButtonLabel,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF083344),
                  foregroundColor: const Color(0xFF67E8F9),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          if (ocrHelpText != null) ...[
            SizedBox(height: showOcrButton ? 8 : 0),
            Text(
              ocrHelpText!,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canBuildDrafts ? onBuildDrafts : null,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Metinden ürün oluştur'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF22D3EE),
                side: const BorderSide(color: Color(0xFF155E75)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (autoCatalogMessage != null) ...[
            const SizedBox(height: 10),
            _AutoCatalogStatus(
              message: autoCatalogMessage!,
              isError: isAutoCatalogError,
            ),
          ],
          const SizedBox(height: 12),
          if (candidates.isEmpty)
            const Text(
              'Henüz aday yok. Metin içinde fiyat veya ürün adı yazınca burada görünür.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                height: 1.35,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  candidates.map((candidate) {
                    final isPrice =
                        candidate.type == XRexTextCandidateType.price;
                    return ActionChip(
                      backgroundColor: const Color(0xFF0B1220),
                      side: BorderSide(
                        color:
                            isPrice
                                ? const Color(0x6634D399)
                                : const Color(0x6606B6D4),
                      ),
                      avatar: Icon(
                        isPrice
                            ? Icons.sell_outlined
                            : Icons.short_text_rounded,
                        size: 16,
                        color:
                            isPrice
                                ? const Color(0xFF22C55E)
                                : const Color(0xFF06B6D4),
                      ),
                      label: Text('${candidate.label}: ${candidate.value}'),
                      onPressed:
                          hasDraft
                              ? () => onApplyToActiveDraft(candidate)
                              : null,
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }
}

class _AutoCatalogStatus extends StatelessWidget {
  final String message;
  final bool isError;

  const _AutoCatalogStatus({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFF97316) : const Color(0xFF06B6D4);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color:
                    isError ? const Color(0xFFFED7AA) : const Color(0xFFA5F3FC),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
