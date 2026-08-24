import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Işıklandırma analizi sonucu veri sınıfı
class _LightingAnalysis {
  final double averageBrightness;
  final int dynamicRange;
  final bool isLowLight;
  final double blurScore;

  const _LightingAnalysis({
    required this.averageBrightness,
    required this.dynamicRange,
    required this.isLowLight,
    required this.blurScore,
  });
}

/// XRex Görüntü Ön İşleme Servisi (Geliştirilmiş)
/// - Çok aşamalı tarama desteği
/// - Gelişmiş ışıklandırma düzeltme
/// - Renk tabanlı etiket filtreleme
/// - Blur giderme filtreleri
class XRexImagePreprocessingService {
  const XRexImagePreprocessingService();

  /// Kameradan gelen ham fatura veya reyon görselini OCR için optimize eder.
  /// [useColorFilter] = true olduğunda fiyat etiketleri için renk filtresi uygulanır.
  /// [aggressiveMode] = true olduğunda düşük ışık koşulları için daha agresif iyileştirme yapılır.
  Future<File> preprocessImageForOcr(
    File inputImageFile, {
    bool useColorFilter = false,
    bool aggressiveMode = false,
  }) async {
    final bytes = await inputImageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) return inputImageFile;

    // 1. Görseli Gri Tonlamaya Çevir (Gürültüyü azaltır)
    img.Image processedImage = img.grayscale(image);

    // 2. Işıklandırma analizi ve adaptif düzeltme
    final lightingAnalysis = _analyzeLighting(processedImage);
    
    if (lightingAnalysis.isLowLight || aggressiveMode) {
      // Düşük ışık koşulları: Gamma düzeltmesi + histogram eşitleme
      processedImage = _applyLowLightCorrection(processedImage, lightingAnalysis);
    } else {
      // Normal koşullar: Basit kontrast artırma
      final brightness = lightingAnalysis.averageBrightness;
      final contrastValue = brightness < 100 ? 1.6 : 1.3;
      processedImage = img.adjustColor(
        processedImage,
        contrast: contrastValue,
      );
    }

    // 3. Keskinlik (Sharpness) Ekle - OCR doğruluğunu artırır
    processedImage = img.convolution(
      processedImage,
      filter: [
         0, -1,  0,
        -1,  5, -1,
         0, -1,  0,
      ],
    );

    // 4. Blur giderme (isteğe bağlı, agresif modda)
    if (aggressiveMode && lightingAnalysis.blurScore > 0.4) {
      processedImage = _applyDeblurFilter(processedImage);
    }

    // 5. Fiyat etiketi renk filtresi (isteğe bağlı)
    if (useColorFilter) {
      processedImage = filterPriceTagColors(processedImage);
    }

    // Optimize edilmiş görseli geçici dosyaya kaydet
    // JPEG kalitesini artır (95) - OCR doğruluğu için önemli
    final optimizedBytes = Uint8List.fromList(img.encodeJpg(processedImage, quality: 95));
    final directory = inputImageFile.parent;
    final outputPath = '${directory.path}/optimized_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    return File(outputPath).writeAsBytes(optimizedBytes);
  }

  /// Işıklandırma analizi sonucu
  _LightingAnalysis _analyzeLighting(img.Image image) {
    int totalLuminance = 0;
    int minLuminance = 255;
    int maxLuminance = 0;
    int pixelCount = 0;
    final step = math.max(1, (image.width ~/ 40));

    // Basit Laplacian varyansı ile blur tespiti
    double variance = 0;
    final grayscale = img.grayscale(image);
    
    for (int y = 1; y < image.height - 1; y += step) {
      for (int x = 1; x < image.width - 1; x += step) {
        final center = grayscale.getPixel(x, y).r.toInt();
        final left = grayscale.getPixel(x - 1, y).r.toInt();
        final right = grayscale.getPixel(x + 1, y).r.toInt();
        final top = grayscale.getPixel(x, y - 1).r.toInt();
        final bottom = grayscale.getPixel(x, y + 1).r.toInt();
        
        // Laplacian operatörü
        final laplacian = (4 * center - left - right - top - bottom).abs();
        variance += laplacian * laplacian;
        
        final luminance = (center * 0.299 + center * 0.587 + center * 0.114).round();
        totalLuminance += luminance;
        if (luminance < minLuminance) minLuminance = luminance;
        if (luminance > maxLuminance) maxLuminance = luminance;
        pixelCount++;
      }
    }

    final avgBrightness = pixelCount > 0 ? (totalLuminance / pixelCount) : 128.0;
    final dynamicRange = maxLuminance - minLuminance;
    final blurScore = pixelCount > 0 ? (variance / pixelCount) / 10000.0 : 0.0;

    return _LightingAnalysis(
      averageBrightness: avgBrightness,
      dynamicRange: dynamicRange,
      isLowLight: avgBrightness < 90,
      blurScore: blurScore.clamp(0.0, 1.0),
    );
  }

  /// Düşük ışık düzeltmesi uygular
  img.Image _applyLowLightCorrection(img.Image image, _LightingAnalysis analysis) {
    // Gamma düzeltmesi (düşük ışıkta daha güçlü)
    final gamma = analysis.averageBrightness < 60 ? 1.8 : 1.4;
    
    // Histogram eşitleme için basit yaklaşım
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = pixel.r.toDouble();
        
        // Gamma düzeltmesi
        final corrected = 255.0 * math.pow(gray / 255.0, 1.0 / gamma);
        final clamped = corrected.clamp(0.0, 255.0).toInt();
        
        result.setPixel(x, y, img.ColorRgb8(clamped, clamped, clamped));
      }
    }
    
    // Kontrastı hafifçe artır
    return img.adjustColor(result, contrast: 1.4);
  }

  /// Blur giderme filtresi (basit Wiener benzeri yaklaşım)
  img.Image _applyDeblurFilter(img.Image image) {
    // Unsharp mask tekniği
    final blurred = img.gaussianBlur(image, radius: 1);
    final result = img.Image(width: image.width, height: image.height);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);
        
        // Unsharp masking: original + amount * (original - blurred)
        final r = (orig.r + 1.5 * (orig.r - blur.r)).clamp(0, 255).toInt();
        final g = (orig.g + 1.5 * (orig.g - blur.g)).clamp(0, 255).toInt();
        final b = (orig.b + 1.5 * (orig.b - blur.b)).clamp(0, 255).toInt();
        
        result.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }
    
    return result;
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
