# tools.shelf - Troubleshooting Rehberi

## Yaygın Hatalar ve Çözümleri

### 1. Model İndirme / Yükleme Hataları

#### `FileNotFoundError: yolov8n.pt not found`
```bash
# Çözüm: Modeli indir
python tools/shelf/download_models.py
# veya
yolo download yolov8n.pt
```

#### `RuntimeError: Engine 'paddle_static' is unavailable`
```bash
# Çözüm: paddlepaddle kur
pip install paddlepaddle
# Windows'ta bazen wheel sorunu olabilir:
pip install paddlepaddle -f https://www.paddlepaddle.org.cn/whl/windows/mkl/avx/stable.html
```

#### `ModuleNotFoundError: No module named 'ultralytics'`
```bash
pip install ultralytics
```

#### `ModuleNotFoundError: No module named 'onnxruntime'`
```bash
pip install onnxruntime
# GPU için:
pip install onnxruntime-gpu
```

### 2. OCR Hataları

#### `ValueError: Unknown argument: show_log` / `enable_angle_cls` / `use_gpu`
**Neden**: PaddleOCR 3.x API değişti. Eski parametreler kaldırıldı.

**Çözüm**: `tools/shelf/ocr.py` zaten güncellenmiş. En son versiyona güncelleyin.

#### `OCR çok yavaş / memory error`
```python
# Batch size küçült
ocr = ShelfOCR(rec_batch_num=5)  # varsayılan 10

# Veya GPU kullan
ocr = ShelfOCR(use_gpu=True)  # CUDA varsa
```

#### `Fiyatlar okunmuyor / yanlış okunuyor`
```python
# Conf threshold düşür
ocr = ShelfOCR(text_rec_score_thresh=0.3)  # varsayılan 0.5

# Veya custom price pattern ekle
ocr = ShelfOCR()
# tools/shelf/ocr.py PRICE_PATTERNS listesine ekle
```

### 3. Detection Hataları

#### `Hiç detection yok (boş liste)`
```python
# Conf threshold düşür
products = scan_shelf("img.jpg", conf_thresh=0.05, device="cpu")

# Retail only kapat (tüm COCO sınıfları)
products = scan_shelf("img.jpg", retail_only=False)

# Model fine-tune edilmedi - COCO sınıfları market ürünlerini kapsamaz
# Production için fine-tune gerekli (bkz. Fine-tune rehberi)
```

#### `Fazla false positive`
```python
# Conf threshold artır
products = scan_shelf("img.jpg", conf_thresh=0.5)

# IOU threshold ayarla
detector = ShelfDetector(iou_thresh=0.3)  # varsayılan 0.45
```

#### `CUDA out of memory`
```python
# Batch size azalt
# Img size küçült
detector = ShelfDetector(imgsz=416, device="cuda")

# Veya CPU kullan
products = scan_shelf("img.jpg", device="cpu")
```

### 4. Matching Hataları

#### `Fiyatlar yanlış ürünle eşleşiyor`
```python
# Max distance küçült
matcher = create_matcher(max_distance=0.10)

# Vertical weight artır (fiyat altta olmalı)
matcher = create_matcher(vertical_weight=0.4, distance_weight=0.3)

# Hungarian algorithm kullan (yoğun raflar için)
matcher = create_matcher(use_hungarian=True)  # scipy gerekli
```

#### `Hiç fiyat eşleşmiyor`
```python
# Max distance artır
matcher = create_matcher(max_distance=0.25)

# OCR confidence threshold düşür
ocr = ShelfOCR(text_rec_score_thresh=0.3)
```

### 4. Export Hataları

#### `CSV boş / header only`
```python
# Products boş - detection/OCR çalışmıyor
# Yukarıdaki detection/OCR çözümlerini dene
```

#### `JSON serialization error`
```python
# numpy tipleri serialize edilemez
# tools/shelf/parser.py zaten float/int'e çeviriyor
# Custom exporter yazıyorsanız: default=str kullan
```

### 5. Performans Sorunları

#### `Çok yavaş (CPU'da 10s+)`
```python
# 1. ONNX export + ONNX Runtime
optimizer.export_onnx("model.onnx")
# Sonra ONNX session ile inference

# 2. INT8 quantization
optimizer.quantize_onnx_int8("model.onnx", "model_int8.onnx")

# 3. NCNN (mobile/embedded en hızlı)
optimizer.export_ncnn("ncnn_model/")

# 4. Img size küçült
detector = ShelfDetector(imgsz=416)

# 5. Batch OCR
batch_ocr = BatchOCRProcessor(ocr, batch_size=10)
```

#### `Memory leak / RAM artıyor`
```python
# Model cache singleton - zaten implements
# Elle model create etmeyin, scanner.detector property'si kullanın

# OCR sonrası cache temizle
import gc
gc.collect()
```

### 6. Fine-tune Rehberi (Production Accuracy İçin)

#### Veri Seti Hazırlığı
```bash
# 1. Resimleri topla (min 100, ideal 500+ per class)
# 2. LabelImg / CVAT ile bbox annotation
# 3. YOLO format: class_id x_center y_center width height (normalized)

# Klasör yapısı:
dataset/
├── images/
│   ├── train/
│   └── val/
└── labels/
    ├── train/
    └── val/
```

#### Eğitim
```bash
# YOLOv8n fine-tune
yolo detect train data=dataset.yaml model=yolov8n.pt epochs=100 imgsz=640 batch=16

# Resume
yolo detect train resume=True

# En iyi model: runs/detect/train/weights/best.pt
```

#### Model Kullanımı
```python
# Fine-tuned model ile
products = scan_shelf("img.jpg", model_path="best.pt", retail_only=True)
```

### 7. Platform-Specific

#### Windows
- `paddlepaddle` wheel sorunu: Python 3.10/3.11 önerilir
- `onnxruntime-gpu` CUDA 11.x/12.x uyumlu versiyon seçin
- Path uzunluğu 260 karakter limiti: `git config --system core.longpaths true`

#### Linux (Docker)
```dockerfile
FROM python:3.11-slim
RUN apt-get update && apt-get install -y libgl1 libglib2.0-0
RUN pip install ultralytics paddleocr onnxruntime
```

#### Apple Silicon (M1/M2/M3)
```bash
# PyTorch MPS
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# ONNX Runtime CPU (ARM64 native)
pip install onnxruntime

# YOLO device="mps"
products = scan_shelf("img.jpg", device="mps")
```

## Debug Modu

```python
import logging
from tools.shelf.logging_utils import setup_logger

# Debug logger
logger = setup_logger("shelf_scanner", level=logging.DEBUG, json_format=False)

# Scanner ile kullan
scanner = ShelfScanner(conf_thresh=0.1, device="cpu")
result = scanner.scan("shelf.jpg")

# Detaylı loglar stdout'a basılır
```

## Log Analizi

### Hızlı Sorun Tespiti
```bash
# Son 100 log satırı
grep "ERROR\|WARNING" shelf_scanner.log | tail -20

# Performans analizi
grep "duration_ms" shelf_scanner.log | awk '{print $NF}' | sort -n

# Model load süreleri
grep "MODEL_LOAD" shelf_scanner.log
```

## SSS

### Q: COCO model market ürünlerini tanımıyor, ne yapmalı?
**A**: Fine-tune yapın (SKU-110K, RPC dataset) veya Grounding DINO gibi zero-shot detector kullanın.

### Q: OCR Türkçe karakterleri (ğ, ü, ş, ı, ö, ç) okumuyor
**A**: `lang="tr"` parametresi PaddleOCR 3.x'te `PP-OCRv6` modeliyle gelir. `rec_batch_num` artırın.

### Q: Fiyat formatı farklı (1.234,56 vs 1,234.56)
**A**: `tools/shelf/ocr.py` `PRICE_PATTERNS` listesine regex ekleyin.

### Q: Export edilen COCO/YOLO formatı label tool'da açmıyor
**A**: Class mapping kontrol edin. `labels.txt` dosyası class_id:name eşleşmeli.

### Q: MobileSAM segmentation nasıl aktif edilir?
```python
scanner = ShelfScanner(use_segmentation=True)
# mobile-sam ve torch kurulu olmalı
pip install mobile-sam torch
```

### Q: Pipeline'ı async nasıl çalıştırırım?
```python
import asyncio

async def scan_async(image_path):
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, scan_shelf, image_path)
```

## Destek

- **Issues**: GitHub Issues
- **Logs**: `shelf_scanner.log` (JSON format)
- **Version**: `tools.shelf.__version__`