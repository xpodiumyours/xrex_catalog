# XRex Asistan - Web Desteği Planı

## 🎯 Amaç
XRex Asistan'ın tarayıcılarda (Chrome, Firefox, Edge, Safari) çalışabilmesi için gerekli altyapının oluşturulması.

## 📦 Gerekli Paketler (`pubspec.yaml`)
```yaml
dependencies:
  tflite_web: ^0.1.0      # TensorFlow Lite Web desteği
  tflite_web_api: ^0.1.0  # TFLite Web API arayüzü
  universal_html: ^2.2.0  # Platform bağımsız HTML erişimi
  web: ^0.5.0             # Dart web interop
  
dev_dependencies:
  build_runner: ^2.4.0
  build_web_compilers: ^4.0.0
```

## 🏗️ Mimari Değişiklikler

### 1. Platform Specific Implementation (PSI)
Flutter'ın `kIsWeb` özelliği kullanılarak kod dallanması yapılır:

```dart
import 'package:flutter/foundation.dart';
import 'xrex_object_detection_service_io.dart' if (dart.library.html) 'xrex_object_detection_service_web.dart';

class XrexObjectDetectionService {
  static final _service = kIsWeb 
      ? XrexObjectDetectionServiceWeb() 
      : XrexObjectDetectionServiceIO();
      
  Future<List<Map>> detect(...) => _service.detect(...);
}
```

### 2. Oluşturulan Web Servisleri
- ✅ `xrex_tflite_object_detection_service_web.dart`: TFLite Web API entegrasyonu
- ✅ `xrex_image_preprocessing_service_web.dart`: Canvas tabanlı görüntü işleme

### 3. Model Dönüşümü
Mevcut `.tflite` modelleri web için optimize edilmelidir:
- **Quantization:** INT8 veya FLOAT16 formatına çevrilmeli
- **Op Uyumluluğu:** WebGL'de desteklenmeyen operatörler kontrol edilmeli
- **Boyut:** İndirme süresi için model < 10MB olmalı (veya lazy load)

## ⚙️ Konfigürasyon Adımları

### A. `web/index.html` Güncellemesi
```html
<script src="https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-core"></script>
<script src="https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-converter"></script>
<script src="https://cdn.jsdelivr.net/npm/@tensorflow/tfjs-backend-webgl"></script>
```

### B. Asset Yönetimi
Modeller `assets/models/` altında tutulmalı ve `pubspec.yaml`'a eklenmeli:
```yaml
flutter:
  assets:
    - assets/models/ssd_mobilenet_v2.tflite
    - assets/models/labels.txt
```

### C. CORS Politikası
Web'de modeller dış kaynaktan yüklenecekse CORS başlıkları ayarlanmalı veya modeller same-origin'den servis edilmeli.

## 🚀 Performans İpuçları
1. **WebGL Kullanımı:** TFLite Web, arka planda WebGL kullanır. GPU hızlandırma açıksa 5-10x hızlanır.
2. **Thread Sayısı:** `numThreads` parametresi WebGL context sayısını etkiler, genellikle 2-4 idealdir.
3. **Model Önbellekleme:** Tarayıcı cache'i kullanarak modeli tekrar indirmeyi önleyin.
4. **Worker Thread:** Ağır işlemleri Web Worker'a taşıyarak UI donmasını engelleyin.

## 🛠️ Eksikler ve Sonraki Adımlar
- [ ] `pubspec.yaml` dosyasına web paketlerinin eklenmesi
- [ ] `main.dart` içinde platform kontrolü ile servisin yönlendirilmesi
- [ ] Gerçek canvas resize ve normalize fonksiyonlarının `dart:html` ile yazılması
- [ ] Model çıktı parser'ının (_parseOutput) modele göre doldurulması
- [ ] Kamera erişimi için `webcam` paketi entegrasyonu

## 🔍 Test Komutu
```bash
flutter build web --release
flutter run -d chrome
```
