# tools.shelf - Market Rafı Tarama Pipeline

**$0 maliyet, local-first, production-ready** market rafı tarama sistemi.

## Özellikler

- 🔍 **Object Detection**: YOLOv8n (COCO pre-trained, fine-tune hazır)
- 📝 **OCR**: PaddleOCR 3.x (TR/EN, fiyat pattern extraction)
- 🎯 **Spatial Matching**: Geometric heuristics (distance, alignment, vertical preference)
- 📦 **Export**: JSON, CSV, COCO, YOLO formats
- ⚡ **Optimization**: ONNX, NCNN, INT8 quantization, batch OCR
- 🛡️ **Production Ready**: Structured logging, retry policies, timeout guards, error handling
- 🧪 **Tested**: 30+ unit/integration tests

## Kurulum

```bash
# Bağımlılıklar
pip install -r tools/shelf/requirements-shelf.txt

# Modelleri indir
python tools/shelf/download_models.py
```

## Hızlı Başlangıç

```python
from tools.shelf import scan_shelf, ShelfScanner

# Basit API
products = scan_shelf("shelf.jpg", conf_thresh=0.25, device="cpu")

# Gelişmiş kullanım
scanner = ShelfScanner(
    conf_thresh=0.25,
    device="cpu",
    retail_only=False,
    max_match_dist=0.15,
)
result = scanner.scan("shelf.jpg")

# Sonuçları dışa aktar
scanner.export_json(result, "output.json")
scanner.export_csv(result, "output.csv")
```

## Çıktı Formatı

```json
{
  "metadata": {"source": "shelf.jpg", "image_shape": [480, 640]},
  "stats": {
    "total_time_ms": 2847.3,
    "detection_time_ms": 1200.1,
    "ocr_time_ms": 1500.2,
    "match_time_ms": 47.0,
    "num_detections": 45,
    "num_products": 38,
    "num_with_price": 32
  },
  "products": [
    {
      "label": "bottle",
      "confidence": 0.87,
      "bbox": [120, 80, 200, 280],
      "bbox_norm": [0.187, 0.167, 0.312, 0.583],
      "center": [0.25, 0.375],
      "price": 45.90,
      "price_confidence": 0.92,
      "match_score": 0.023
    }
  ]
}
```

## Konfigürasyon

| Parametre | Varsayılan | Açıklama |
|-----------|------------|----------|
| `conf_thresh` | 0.25 | Detection confidence threshold (0-1) |
| `device` | "cpu" | "cpu" or "cuda" |
| `retail_only` | False | Sadece retail COCO sınıflarını filtrele |
| `max_match_dist` | 0.15 | Max normalized distance for price matching |
| `crop_padding` | 0.1 | Crop padding ratio |
| `ocr_lang` | "tr" | OCR language |

## Optimizasyon

```python
from tools.shelf.optimize import ModelOptimizer

optimizer = ModelOptimizer("yolov8n.pt", device="cpu")

# ONNX export
optimizer.export_onnx("model.onnx", imgsz=640, half=False)

# INT8 quantization
optimizer.quantize_onnx_int8("model.onnx", "model_int8.onnx")

# NCNN (mobile)
optimizer.export_ncnn("ncnn_model/")

# Benchmark
import cv2
img = cv2.imread("shelf.jpg")
print(optimizer.benchmark(img, iterations=10))
```

## Test

```bash
# Tüm testler
python -m pytest tools/shelf/tests/ -v

# Sadece matcher testleri
python -m pytest tools/shelf/tests/test_matcher.py -v
```

## Mimari

```
tools/shelf/
├── __init__.py          # Public API
├── detector.py          # YOLOv8n wrapper
├── ocr.py               # PaddleOCR wrapper
├── matcher.py           # Spatial price-product matching
├── parser.py            # Pipeline orchestration
├── exporter.py          # Export utilities
├── segmenter.py         # MobileSAM (optional)
├── optimize.py          # ONNX/NCNN/INT8 optimization
├── logging_utils.py     # Structured logging & error handling
├── requirements-shelf.txt
├── download_models.py
└── tests/
    ├── test_matcher.py
    └── test_pipeline.py
```

## Accuracy

| Model | Baseline (COCO) | Fine-tuned (100-200 img) |
|-------|-----------------|--------------------------|
| YOLOv8n | %50-60 | %80-90 |
| YOLOv8s | %60-70 | %85-95 |

**Not**: COCO pre-trained model market ürünleri için optimize edilmedi. Production için fine-tuning önerilir (SKU-110K, RPC datasets).

## Lisans

MIT License