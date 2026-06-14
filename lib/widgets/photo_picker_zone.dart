import 'package:flutter/material.dart';

import 'xrex_glass_panel.dart';

class PhotoPickerZone extends StatelessWidget {
  final VoidCallback onPick;
  final bool hasImage;

  const PhotoPickerZone({
    super.key,
    required this.onPick,
    required this.hasImage,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(22),
      child: XRexGlassPanel(
        padding: const EdgeInsets.all(22),
        accentColor:
            hasImage ? const Color(0xFF22C55E) : const Color(0xFF06B6D4),
        strongGlow: hasImage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            XRexSectionHeader(
              icon:
                  hasImage
                      ? Icons.check_circle_outline_rounded
                      : Icons.add_photo_alternate_outlined,
              eyebrow: 'SOURCE INPUT',
              title:
                  hasImage
                      ? 'Fotoğraf seçildi'
                      : 'Fotoğraf veya ekran görüntüsü seç',
              trailing: hasImage ? 'READY' : 'LOCAL',
            ),
            const SizedBox(height: 14),
            const Text(
              'Raf, reyon, çoklu ürün fotoğrafı veya e-ticaret ekran görüntüsü kullanabilirsiniz.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
