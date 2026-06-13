import 'package:flutter/material.dart';

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
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1728),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF1F2A3D)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3306B6D4),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasImage
                  ? Icons.check_circle_outline_rounded
                  : Icons.add_photo_alternate_outlined,
              color:
                  hasImage ? const Color(0xFF22C55E) : const Color(0xFF06B6D4),
              size: 30,
            ),
            const SizedBox(height: 14),
            Text(
              hasImage
                  ? 'Fotoğraf seçildi'
                  : 'Fotoğraf veya ekran görüntüsü seç',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
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
