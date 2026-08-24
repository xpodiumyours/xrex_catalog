# tools.shelf - Mimari Dokümantasyonu

## Genel Bakış

tools.shelf, market raflarından ürün ve fiyat bilgisi çıkaran **modüler, test edilebilir, production-ready** bir pipeline'dır.

## Veri Akışı

```
┌─────────────┐
│   Input     │  shelf.jpg / numpy array
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  Preprocessing  │  Resize (640x640), normalize
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Detection     │  YOLOv8n → List[bbox, class, conf]
│   (YOLOv8n)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Cropping      │  Her detection için crop (+10% padding)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│      OCR        │  PaddleOCR 3.x → List[text, conf, bbox]
│  (PaddleOCR)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Price Filter   │  Regex: \d+[.,]\d{2} + currency suffixes
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Spatial Match   │  Geometric heuristic:
│   (Matcher)     │  - Center distance (50%)
│                 │  - Horizontal alignment (30%)
│                 │  - Vertical preference (20%)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Export       │  JSON / CSV / COCO / YOLO
└─────────────────┘
```

## Modül Sorumlulukları

| Modül | Sorumluluk | Bağımlılıklar |
|-------|------------|---------------|
| `detector.py` | YOLOv8n inference, export | ultralytics |
| `ocr.py` | PaddleOCR inference, price extraction | paddleocr |
| `matcher.py` | Spatial matching heuristics | - (pure Python) |
| `parser.py` | Pipeline orchestration | detector, ocr, matcher |
| `exporter.py` | Multi-format export | - (stdlib) |
| `segmenter.py` | MobileSAM segmentation (optional) | mobile-sam, torch |
| `optimize.py` | ONNX/NCNN/INT8, batch OCR | onnxruntime |
| `logging_utils.py` | Structured logging, errors, retry | - (stdlib) |

## Matching Algoritması

### Skorlama Fonksiyonu

```
score = distance * 0.50 - h_align * 0.30 - v_pref * 0.20

where:
  distance = Euclidean distance (normalized [0,1])
  h_align  = 1.0 - min(|px - qx| / 0.3, 1.0)  # same row bonus
  v_pref   = 1.0 if price below product else 0.5
```

### Parametreler

| Parametre | Varsayılan | Etki |
|-----------|------------|------|
| `max_distance` | 0.15 | Max normalized center distance |
| `distance_weight` | 0.50 | Mesafe cezası ağırlığı |
| `horizontal_weight` | 0.30 | Aynı satır bonusu |
| `vertical_weight` | 0.20 | Alt tarafta fiyat tercihi |
| `vertical_preference` | True | Fiyat ürünün altındaysa bonus |

### Hungarian Algorithm (Opsiyonel)

`scipy.optimize.linear_sum_assignment` ile optimal assignment. Greedy matching başarısız olursa (yoğun raflar) kullanılır.

## Hata Yönetimi

### Exception Hiyerarşisi

```
ScanError (base)
├── ModelLoadError
├── OCRError
├── MatchingError
└── ExportError
```

### Retry Policies

| İşlem | Max Retries | Base Delay | Exponential Base |
|-------|-------------|------------|------------------|
| Model Load | 2 | 2.0s | 2.0 |
| OCR | 3 | 0.5s | 2.0 |
| Export | 2 | 1.0s | 2.0 |

### Timeout Guard

```python
with TimeoutGuard(30.0, "full_scan"):
    result = scanner.scan(image)
```

## Logging

### JSON Format

```json
{
  "timestamp": "2026-08-24T12:30:45.123Z",
  "level": "INFO",
  "logger": "shelf_scanner",
  "message": "scan completed",
  "function": "scan",
  "duration_ms": 2847.3,
  "status": "success",
  "function": "scan"
}
```

### Log Seviyeleri

- **DEBUG**: Detailed flow, crop coordinates
- **INFO**: Scan start/end, stats, model loading
- **WARNING**: Retry attempts, low confidence detections
- **ERROR**: Failed operations, exceptions

## Optimizasyon Stratejileri

### 1. Model Export

| Format | Kullanım Alanı | Hız Artışı |
|--------|----------------|------------|
| ONNX + ONNX Runtime | CPU/GPU inference | 2-3x |
| ONNX INT8 | CPU inference | 3-4x |
| NCNN | Mobile/Embedded | En hızlı CPU |
| TFLite | Mobile/Edge | Optimized |

### 2. Batch OCR

- 10 crop tek forward pass
- PaddleOCR `rec_batch_num=10` kullanır
- ~40% OCR hız artışı

### 3. Model Cache

- Lazy singleton pattern
- Warmup script ile cold start eliminasyonu

## Performans Hedefleri

| Metrik | CPU (YOLOv8n) | GPU (YOLOv8n) | ONNX INT8 CPU |
|--------|---------------|---------------|---------------|
| Detection | ~1200ms | ~150ms | ~400ms |
| OCR (10 crop) | ~1500ms | ~400ms | ~1500ms |
| Matching | ~50ms | ~10ms | ~50ms |
| **Total** | **~3-5s** | **~1s** | **~2-3s** |

## Güvenlik

- **Veri dışarı çıkmaz** - Tüm işlem local
- **Model weights** - `.gitignore` ile korunur
- **Geçici dosyalar** - İşlem sonrası temizlenir
- **Loglama** - Sadece metrikler, görüntü loglanmaz

## Genişletilebilirlik

### Yeni Detector Ekleme

```python
class CustomDetector:
    def predict(self, image: np.ndarray) -> List[Dict]:
        # Return: [{bbox, class_id, class_name, conf, center}, ...]
        pass
```

### Yeni Matcher Ekleme

```python
class CustomMatcher:
    def match(self, products: List[Dict], prices: List[Dict]) -> List[Dict]:
        pass
```

### Yeni Exporter Ekleme

```python
def export_custom(products: List[Dict], output_path: str, **kwargs):
    pass
```

## Test Stratejisi

| Test Türü | Dosya | Kapsam |
|-----------|-------|--------|
| Unit | `test_matcher.py` | Matcher heuristics, edge cases |
| Integration | `test_pipeline.py` | Full pipeline, exporters, error handling |
| Accuracy | (manual) | Golden JSON vs output diff |

## Versiyonlama

- **Semantic Versioning**: MAJOR.MINOR.PATCH
- **Current**: v0.1.0-shelf
- **Breaking Changes**: MAJOR bump