"""tools.shelf.optimize - Optimization utilities (ONNX, NCNN, INT8, batch processing)"""

import os
import time
import subprocess
from pathlib import Path
from typing import Optional, List, Dict, Any
import numpy as np

try:
    import onnxruntime as ort
    ONNXRUNTIME_AVAILABLE = True
except ImportError:
    ONNXRUNTIME_AVAILABLE = False

try:
    from ultralytics import YOLO
except ImportError:
    YOLO = None


class ModelOptimizer:
    """Model optimization utilities for shelf scanner."""
    
    def __init__(self, model_path: str = "yolov8n.pt", device: str = "cpu"):
        self.model_path = model_path
        self.device = device
        self.model = None
        if YOLO:
            self.model = YOLO(model_path)
            self.model.to(device)
    
    def export_onnx(
        self,
        output_path: str,
        imgsz: int = 640,
        half: bool = False,
        simplify: bool = True,
        opset: int = 12,
    ) -> str:
        """Export YOLO model to ONNX format."""
        if not self.model:
            raise RuntimeError("YOLO model not loaded")
        
        result = self.model.export(
            format="onnx",
            imgsz=imgsz,
            half=half,
            simplify=simplify,
            opset=opset,
        )
        
        # Move to desired output path if different
        if Path(result).resolve() != Path(output_path).resolve():
            import shutil
            shutil.move(result, output_path)
        
        return output_path
    
    def export_ncnn(self, output_dir: str, imgsz: int = 640) -> str:
        """Export YOLO model to NCNN format (mobile/embedded)."""
        if not self.model:
            raise RuntimeError("YOLO model not loaded")
        
        result = self.model.export(
            format="ncnn",
            imgsz=imgsz,
        )
        
        return result
    
    def export_tflite(
        self,
        output_path: str,
        imgsz: int = 640,
        int8: bool = False,
    ) -> str:
        """Export YOLO model to TFLite format."""
        if not self.model:
            raise RuntimeError("YOLO model not loaded")
        
        result = self.model.export(
            format="tflite",
            imgsz=imgsz,
            int8=int8,
        )
        
        if Path(result).resolve() != Path(output_path).resolve():
            import shutil
            shutil.move(result, output_path)
        
        return output_path
    
    def quantize_onnx_int8(
        self,
        onnx_path: str,
        output_path: str,
        calibration_data: Optional[np.ndarray] = None,
    ) -> str:
        """Quantize ONNX model to INT8 using ONNX Runtime."""
        if not ONNXRUNTIME_AVAILABLE:
            raise RuntimeError("onnxruntime not installed. Run: pip install onnxruntime")
        
        from onnxruntime.quantization import quantize_dynamic, QuantType
        
        quantize_dynamic(
            model_input=onnx_path,
            model_output=output_path,
            weight_type=QuantType.QInt8,
        )
        
        return output_path
    
    def benchmark(
        self,
        image: np.ndarray,
        iterations: int = 10,
        warmup: int = 3,
    ) -> Dict[str, float]:
        """Benchmark inference speed."""
        if not self.model:
            raise RuntimeError("YOLO model not loaded")
        
        # Warmup
        for _ in range(warmup):
            self.model.predict(image, verbose=False, device=self.device)
        
        # Benchmark
        times = []
        for _ in range(iterations):
            start = time.perf_counter()
            self.model.predict(image, verbose=False, device=self.device)
            times.append(time.perf_counter() - start)
        
        times = np.array(times)
        
        return {
            "mean_ms": float(times.mean() * 1000),
            "std_ms": float(times.std() * 1000),
            "min_ms": float(times.min() * 1000),
            "max_ms": float(times.max() * 1000),
            "fps": float(1.0 / times.mean()),
        }
    
    def benchmark_onnx(
        self,
        onnx_path: str,
        image: np.ndarray,
        iterations: int = 10,
        warmup: int = 3,
        providers: Optional[List[str]] = None,
    ) -> Dict[str, float]:
        """Benchmark ONNX model with ONNX Runtime."""
        if not ONNXRUNTIME_AVAILABLE:
            raise RuntimeError("onnxruntime not installed")
        
        if providers is None:
            providers = ['CPUExecutionProvider']
        
        session = ort.InferenceSession(onnx_path, providers=providers)
        input_name = session.get_inputs()[0].name
        
        # Preprocess image (YOLO expects normalized [0,1] RGB)
        img = image.astype(np.float32) / 255.0
        img = img.transpose(2, 0, 1)  # HWC -> CHW
        img = np.expand_dims(img, axis=0)  # Add batch dim
        
        # Warmup
        for _ in range(warmup):
            session.run(None, {input_name: img})
        
        # Benchmark
        times = []
        for _ in range(iterations):
            start = time.perf_counter()
            session.run(None, {input_name: img})
            times.append(time.perf_counter() - start)
        
        times = np.array(times)
        
        return {
            "mean_ms": float(times.mean() * 1000),
            "std_ms": float(times.std() * 1000),
            "min_ms": float(times.min() * 1000),
            "max_ms": float(times.max() * 1000),
            "fps": float(1.0 / times.mean()),
        }


class BatchOCRProcessor:
    """Batch OCR processor for multiple crops."""
    
    def __init__(self, ocr, batch_size: int = 10):
        self.ocr = ocr
        self.batch_size = batch_size
    
    def process_crops(self, image: np.ndarray, crops: List[Dict]) -> List[Dict]:
        """Process multiple crops in batches."""
        results = []
        
        for i in range(0, len(crops), self.batch_size):
            batch = crops[i:i + self.batch_size]
            batch_images = []
            batch_infos = []
            
            h, w = image.shape[:2]
            
            for crop_info in batch:
                x1, y1, x2, y2 = crop_info["bbox"]
                pad_x = int((x2 - x1) * 0.1)
                pad_y = int((y2 - y1) * 0.1)
                x1p = max(0, x1 - pad_x)
                y1p = max(0, y1 - pad_y)
                x2p = min(w, x2 + pad_x)
                y2p = min(h, y2 + pad_y)
                
                crop_img = image[y1p:y2p, x1p:x2p]
                if crop_img.size > 0:
                    batch_images.append(crop_img)
                    batch_infos.append((crop_info, x1p, y1p))
            
            if not batch_images:
                continue
            
            # Batch OCR
            ocr_results = self.ocr.ocr(batch_images)
            
            for (crop_info, ox, oy), ocr_result in zip(batch_infos, ocr_results):
                texts = []
                if ocr_result and len(ocr_result) > 0:
                    for item in ocr_result[0]:
                        if isinstance(item, dict):
                            texts_list = item.get('rec_texts', [])
                            scores_list = item.get('rec_scores', [])
                            boxes_list = item.get('rec_boxes', [])
                            polys_list = item.get('dt_polys', [])
                            
                            for text, conf, box, poly in zip(texts_list, scores_list, boxes_list, polys_list):
                                if isinstance(box, (list, np.ndarray)):
                                    if len(box) == 4:
                                        bbox = [[box[0], box[1]], [box[2], box[1]], [box[2], box[3]], [box[0], box[3]]]
                                    else:
                                        bbox = [[p[0], p[1]] for p in np.array(box).reshape(-1, 2)]
                                else:
                                    bbox = poly if poly else []
                                
                                xs = [p[0] for p in bbox] if bbox else [0,0,0,0]
                                ys = [p[1] for p in bbox] if bbox else [0,0,0,0]
                                cx = sum(xs) / len(xs) / w if xs else 0
                                cy = sum(ys) / len(ys) / h if ys else 0
                                
                                texts.append({
                                    "text": text.strip(),
                                    "confidence": float(conf),
                                    "bbox": bbox,
                                    "center": (cx, cy),
                                    "bbox_norm": [[p[0]/w, p[1]/h] for p in bbox] if bbox else [],
                                })
                
                crop_info["ocr_results"] = texts
                results.append(crop_info)
        
        return results


def create_optimizer(model_path: str = "yolov8n.pt", device: str = "cpu") -> ModelOptimizer:
    """Factory function."""
    return ModelOptimizer(model_path, device)


def create_batch_ocr(ocr, batch_size: int = 10) -> BatchOCRProcessor:
    """Factory function."""
    return BatchOCRProcessor(ocr, batch_size)