"""tools.shelf.parser - Raf Tarama Pipeline Orchestrator

Main entry point: scan_shelf(image_path) -> List[Dict]
Combines: Detection -> Crop -> OCR -> Price Filter -> Spatial Match -> Export
"""

from typing import List, Dict, Any, Optional, Union
from pathlib import Path
import cv2
import numpy as np
import json
import time
from dataclasses import dataclass, asdict

from .detector import ShelfDetector, create_detector
from .ocr import ShelfOCR, create_ocr
from .matcher import PriceProductMatcher, create_matcher


@dataclass
class ScanResult:
    """Tarama sonucu veri sınıfı."""
    products: List[Dict[str, Any]]
    stats: Dict[str, Any]
    metadata: Dict[str, Any]


class ShelfScanner:
    """Raf tarama ana sınıfı - yapılandırılabilir pipeline."""
    
    def __init__(
        self,
        # Detector config
        model_path: Optional[str] = None,
        conf_thresh: float = 0.25,
        iou_thresh: float = 0.45,
        device: str = "cpu",
        imgsz: int = 640,
        retail_only: bool = False,
        # OCR config
        ocr_lang: str = "tr",
        ocr_use_gpu: bool = False,
        # Matcher config
        max_match_dist: float = 0.15,
        # Processing
        crop_padding: float = 0.1,
        min_crop_size: int = 32,
    ):
        self.crop_padding = crop_padding
        self.min_crop_size = min_crop_size
        
        # Initialize components lazily
        self._detector = None
        self._ocr = None
        self._matcher = None
        
        # Config storage
        self.detector_config = {
            "model_path": model_path,
            "conf_thresh": conf_thresh,
            "iou_thresh": iou_thresh,
            "device": device,
            "imgsz": imgsz,
            "retail_only": retail_only,
        }
        self.ocr_config = {
            "lang": ocr_lang,
            "use_gpu": ocr_use_gpu,
        }
        self.matcher_config = {
            "max_distance": max_match_dist,
        }
    
    @property
    def detector(self) -> ShelfDetector:
        if self._detector is None:
            self._detector = create_detector(**self.detector_config)
        return self._detector
    
    @property
    def ocr(self) -> ShelfOCR:
        if self._ocr is None:
            self._ocr = create_ocr(**self.ocr_config)
        return self._ocr
    
    @property
    def matcher(self) -> PriceProductMatcher:
        if self._matcher is None:
            self._matcher = create_matcher(**self.matcher_config)
        return self._matcher
    
    def scan(self, image_input: Union[str, np.ndarray]) -> ScanResult:
        """
        Ana tarama fonksiyonu.
        
        Args:
            image_input: Dosya yolu (str) veya BGR numpy array
            
        Returns:
            ScanResult with products, stats, metadata
        """
        start_time = time.time()
        
        # Load image
        if isinstance(image_input, str):
            image_path = image_input
            image = cv2.imread(image_input)
            if image is None:
                raise FileNotFoundError(f"Image not found: {image_input}")
            metadata = {"source": image_input}
        else:
            image = image_input
            image_path = "array_input"
            metadata = {"source": "numpy_array"}
        
        h, w = image.shape[:2]
        metadata["image_shape"] = [h, w]
        
        # 1. DETECTION
        t0 = time.time()
        detections = self.detector.predict(image)
        detection_time = time.time() - t0
        
        # Filter by minimum crop size
        valid_detections = []
        for det in detections:
            x1, y1, x2, y2 = det["bbox"]
            if (x2 - x1) >= self.min_crop_size and (y2 - y1) >= self.min_crop_size:
                valid_detections.append(det)
        
        # 2. CROP & OCR
        t0 = time.time()
        crops = self._prepare_crops(image, valid_detections)
        crops_with_ocr = self.ocr.ocr_crops(image, crops)
        ocr_time = time.time() - t0
        
        # 3. PRICE EXTRACTION
        prices = []
        products = []
        for crop in crops_with_ocr:
            ocr_results = crop.get("ocr_results", [])
            found_prices = self.ocr.find_prices(ocr_results)
            
            # Base product info
            product = {
                "label": crop["class_name"],
                "detection_conf": crop["conf"],
                "bbox": crop["bbox"],
                "bbox_norm": crop["bbox_norm"],
                "center": crop["center"],
                "class_id": crop["class_id"],
                "ocr_results": ocr_results,
            }
            
            if found_prices:
                # Multiple prices found - keep all for matcher
                for p in found_prices:
                    prices.append(p)
                product["raw_prices"] = found_prices
            
            products.append(product)
        
        # 4. SPATIAL MATCHING
        t0 = time.time()
        matched_products = self.matcher.match(products, prices)
        match_time = time.time() - t0
        
        # 5. POST-PROCESS
        final_products = []
        for prod in matched_products:
            # Clean output
            output = {
                "label": prod["label"],
                "confidence": round(prod["detection_conf"], 3),
                "bbox": prod["bbox"],
                "bbox_norm": [round(v, 4) for v in prod["bbox_norm"]],
                "center": [round(v, 4) for v in prod["center"]],
            }
            
            if "price" in prod and prod["price"] is not None:
                output["price"] = round(prod["price"], 2)
                output["price_confidence"] = round(prod.get("price_confidence", 0), 3)
                output["match_score"] = round(prod.get("match_score", 0), 4)
            
            final_products.append(output)
        
        total_time = time.time() - start_time
        
        # Stats
        stats = {
            "total_time_ms": round(total_time * 1000, 1),
            "detection_time_ms": round(detection_time * 1000, 1),
            "ocr_time_ms": round(ocr_time * 1000, 1),
            "match_time_ms": round(match_time * 1000, 1),
            "num_detections": len(detections),
            "num_valid": len(valid_detections),
            "num_products": len(final_products),
            "num_with_price": sum(1 for p in final_products if "price" in p),
        }
        
        return ScanResult(
            products=final_products,
            stats=stats,
            metadata=metadata,
        )
    
    def _prepare_crops(self, image: np.ndarray, detections: List[Dict]) -> List[Dict]:
        """Detection'lardan crop bilgileri hazırlar."""
        h, w = image.shape[:2]
        crops = []
        
        for det in detections:
            x1, y1, x2, y2 = det["bbox"]
            
            # Padding
            pad_x = int((x2 - x1) * self.crop_padding)
            pad_y = int((y2 - y1) * self.crop_padding)
            x1p = max(0, x1 - pad_x)
            y1p = max(0, y1 - pad_y)
            x2p = min(w, x2 + pad_x)
            y2p = min(h, y2 + pad_y)
            
            crop = {
                "bbox": [x1, y1, x2, y2],
                "bbox_norm": det["bbox_norm"],
                "class_id": det["class_id"],
                "class_name": det["class_name"],
                "conf": det["conf"],
                "center": det["center"],
                "crop_coords": [x1p, y1p, x2p, y2p],
            }
            crops.append(crop)
        
        return crops
    
    def scan_path(self, image_path: str) -> ScanResult:
        """Dosya yolu ile tarama (scan wrapper)."""
        return self.scan(image_path)
    
    def export_json(self, result: ScanResult, output_path: str) -> None:
        """Sonuçları JSON dosyasına yaz."""
        output = {
            "metadata": result.metadata,
            "stats": result.stats,
            "products": result.products,
        }
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(output, f, ensure_ascii=False, indent=2)
    
    def export_csv(self, result: ScanResult, output_path: str) -> None:
        """Sonuçları CSV dosyasına yaz."""
        import csv
        if not result.products:
            return
        
        fieldnames = ["label", "confidence", "price", "price_confidence", 
                      "bbox_x1", "bbox_y1", "bbox_x2", "bbox_y2"]
        
        with open(output_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for p in result.products:
                row = {
                    "label": p["label"],
                    "confidence": p["confidence"],
                    "price": p.get("price", ""),
                    "price_confidence": p.get("price_confidence", ""),
                    "bbox_x1": p["bbox"][0],
                    "bbox_y1": p["bbox"][1],
                    "bbox_x2": p["bbox"][2],
                    "bbox_y2": p["bbox"][3],
                }
                writer.writerow(row)


def scan_shelf(
    image_path: str,
    conf_thresh: float = 0.25,
    device: str = "cpu",
    **kwargs,
) -> List[Dict[str, Any]]:
    """
    Basit tek fonksiyonlu API.
    
    Args:
        image_path: Görüntü dosyası yolu
        conf_thresh: Detection confidence threshold
        device: "cpu" or "cuda"
        **kwargs: ShelfScanner config parametreleri
        
    Returns:
        List[Dict]: Ürün listesi (label, confidence, bbox, price, ...)
    """
    scanner = ShelfScanner(conf_thresh=conf_thresh, device=device, **kwargs)
    result = scanner.scan(image_path)
    return result.products


def scan_shelf_array(
    image: np.ndarray,
    conf_thresh: float = 0.25,
    device: str = "cpu",
    **kwargs,
) -> List[Dict[str, Any]]:
    """Numpy array girişi ile tarama."""
    scanner = ShelfScanner(conf_thresh=conf_thresh, device=device, **kwargs)
    result = scanner.scan(image)
    return result.products


# Backward compatibility
def create_scanner(**kwargs) -> ShelfScanner:
    """Factory function."""
    return ShelfScanner(**kwargs)