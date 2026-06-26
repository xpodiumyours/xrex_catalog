import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class XRexImagePreprocessingService {
  const XRexImagePreprocessingService();

  /// Kameradan gelen ham fatura veya reyon görselini OCR için optimize eder.
  Future<File> preprocessImageForOcr(File inputImageFile) async {
    final bytes = await inputImageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) return inputImageFile;

    // 1. Görseli Gri Tonlamaya Çevir (Gürültüyü azaltır)
    final grayscaleImage = img.grayscale(image);

    // 2. Kontrastı Artır (Metinlerin arka plandan ayrışmasını sağlar)
    final highContrastImage = img.adjustColor(
      grayscaleImage,
      contrast: 1.5, // %150 Kontrast oranı
    );

    // 3. Gaussian Blur ile pürüzleri yumuşat
    final blurredImage = img.gaussianBlur(highContrastImage, radius: 1);

    // Optimize edilmiş görseli geçici dosyaya kaydet
    final optimizedBytes = Uint8List.fromList(img.encodeJpg(blurredImage));
    final directory = inputImageFile.parent;
    final outputPath = '${directory.path}/optimized_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    return File(outputPath).writeAsBytes(optimizedBytes);
  }

  /// Bounding Box koordinatlarına göre ürünü görselden kırpar.
  Future<Uint8List?> cropProductFromBoundingBox({
    required File originalImageFile,
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    final bytes = await originalImageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) return null;

    // Koordinat sınırlarının taşmasını önle (Clamping)
    final cropX = x.clamp(0, image.width);
    final cropY = y.clamp(0, image.height);
    final cropW = width.clamp(1, image.width - cropX);
    final cropH = height.clamp(1, image.height - cropY);

    if (cropW <= 0 || cropH <= 0) return null;

    // Dart saf performansıyla görseli kırp
    final croppedImage = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    return Uint8List.fromList(img.encodeJpg(croppedImage));
  }
}
