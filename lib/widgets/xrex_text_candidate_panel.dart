import 'package:flutter/material.dart';

import '../models/xrex_text_candidate.dart';

class XRexTextCandidatePanel extends StatelessWidget {
  final TextEditingController textController;
  final List<XRexTextCandidate> candidates;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<XRexTextCandidate> onApplyToActiveDraft;
  final VoidCallback onBuildDrafts;
  final bool hasDraft;
  final bool canBuildDrafts;

  const XRexTextCandidatePanel({
    super.key,
    required this.textController,
    required this.candidates,
    required this.onTextChanged,
    required this.onApplyToActiveDraft,
    required this.onBuildDrafts,
    required this.hasDraft,
    required this.canBuildDrafts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1728),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF233149)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_search_rounded, color: Color(0xFF06B6D4)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Metin / fiyat adayları',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: textController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Etiketten okuduğun metni buraya yapıştır',
              hintText: 'Örn: Penti çorap 175 TL\nParlak model',
            ),
            onChanged: onTextChanged,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canBuildDrafts ? onBuildDrafts : null,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Metni taslaklara dönüştür'),
            ),
          ),
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
