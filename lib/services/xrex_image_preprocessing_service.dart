import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class XRexImagePreprocessingService {
  const XRexImagePreprocessingService();

  /// Kameradan gelen ham fatura veya reyon görselini OCR için optimize eder.
  /// [useColorFilter] = true olduğunda fiyat etiketleri için renk filtresi uygulanır.
  Future<File> preprocessImageForOcr(File inputImageFile, {bool useColorFilter = false}) async {
    final bytes = await inputImageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return inputImageFile;

    // 1. Görseli Gri Tonlamaya Çevir (Gürültüyü azaltır)
    final grayscaleImage = img.grayscale(image);

    // 2. Kontrastı Artır (Metinlerin arka plandan ayrışmasını sağlar)
    final highContrastImage = img.adjustColor(
      grayscaleImage,
      contrast: 1.8, // %180 Kontrast oranı (eskisi: 1.5)
    );

    // 3. Keskinlik (Sharpness) Ekle - OCR doğruluğunu artırır
    final sharpenedImage = img.convolution(
      highContrastImage,
      filter: [
         0, -1,  0,
        -1,  5, -1,
         0, -1,  0,
      ],
    );

    // 4. Gaussian Blur ile pürüzleri yumuşat (hafif)
    final blurredImage = img.gaussianBlur(sharpenedImage, radius: 1);

    // 5. Fiyat etiketi renk filtresi (isteğe bağlı)
    final processedImage = useColorFilter
        ? filterPriceTagColors(blurredImage)
        : blurredImage;

    // Optimize edilmiş görseli geçici dosyaya kaydet
    final optimizedBytes = Uint8List.fromList(img.encodeJpg(processedImage));
    final directory = inputImageFile.parent;
    final outputPath = '${directory.path}/optimized_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    return File(outputPath).writeAsBytes(optimizedBytes);
  }

  /// Fiyat etiketlerini algılamak için renk filtresi uygular.
  /// Sarı ve kırmızı bölgeleri vurgular (market etiketleri genelde bu renklerdedir).
  img.Image filterPriceTagColors(img.Image image) {
    final result = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Sarı etiket algılama (r > 180, g > 180, b < 100)
        final isYellow = r > 180 && g > 180 && b < 100;
        // Kırmızı etiket algılama (r > 180, g < 100, b < 100)
        final isRed = r > 180 && g < 100 && b < 100;

        if (isYellow || isRed) {
          // Etiket bölgesini beyaz yap (metin kalsın)
          result.setPixel(x, y, img.ColorRgb8(255, 255, 255));
        } else {
          // Diğer bölgeleri koyulaştır
          final gray = (r * 0.299 + g * 0.587 + b * 0.114).toInt();
          final darkened = (gray * 0.5).clamp(0, 255).toInt();
          result.setPixel(x, y, img.ColorRgb8(darkened, darkened, darkened));
        }
      }
    }

    return result;
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
