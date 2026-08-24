"""tools.shelf.ocr - PaddleOCR 3.x Wrapper for Price Tag Recognition

Optimized for retail price tag OCR:
- Turkish/English language support
- Price pattern extraction (TL, €, $, numeric)
- Crop-based recognition with confidence filtering
"""

from typing import List, Dict, Any, Optional, Tuple
import re
import cv2
import numpy as np

try:
    from paddleocr import PaddleOCR
except ImportError:
    PaddleOCR = None


class ShelfOCR:
    """PaddleOCR 3.x tabanlı fiyat etiketi okuyucu."""
    
    # Fiyat pattern'leri (Türkiye + uluslararası)
    PRICE_PATTERNS = [
        r'^\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})$',  # 1.234,56 / 1,234.56
        r'^\d+[.,]\d{2}$',                          # 45,90 / 45.90
        r'^\d+[.,]\d{1}$',                          # 45,9 / 45.9
        r'^\d+$',                                    # 45 (tam sayı)
    ]
    
    CURRENCY_SUFFIXES = ['tl', 'try', '₺', 'eur', '€', 'usd', '$', 'gbp', '£']
    
    def __init__(
        self,
        lang: str = "tr",
        **kwargs,
    ):
        if PaddleOCR is None:
            raise RuntimeError("paddleocr not installed. Run: pip install paddleocr")
        
        # PaddleOCR 3.x minimal API - sadece gerekli parametreler
        self.ocr = PaddleOCR()
        
        # Compile price regex
        self._price_regex = re.compile(
            r'(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|\d+[.,]\d{1,2}|\d+)'
        )
    
    def ocr_image(self, image: np.ndarray) -> List[Dict[str, Any]]:
        """
        Görüntüde metin tanıma yapar.
        
        Returns:
            List[Dict]: {text, confidence, bbox, center}
        """
        h, w = image.shape[:2]
        result = self.ocr.predict(image)
        
        texts = []
        if result and len(result) > 0:
            for item in result[0]:
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
        
        return texts
    
    def ocr_crops(self, image: np.ndarray, crops: List[Dict]) -> List[Dict]:
        """Birden fazla crop bölgesi için batch OCR."""
        h, w = image.shape[:2]
        
        for crop_info in crops:
            x1, y1, x2, y2 = crop_info["bbox"]
            pad_x = int((x2 - x1) * 0.1)
            pad_y = int((y2 - y1) * 0.1)
            x1p = max(0, x1 - pad_x)
            y1p = max(0, y1 - pad_y)
            x2p = min(w, x2 + pad_x)
            y2p = min(h, y2 + pad_y)
            
            crop_img = image[y1p:y2p, x1p:x2p]
            if crop_img.size == 0:
                crop_info["ocr_results"] = []
                continue
                
            result = self.ocr.predict(crop_img)
            
            texts = []
            if result and len(result) > 0:
                for item in result[0]:
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
        
        return crops
    
    def extract_price(self, text: str) -> Optional[float]:
        """Metinden fiyat çıkarır."""
        if not text:
            return None
        
        text_lower = text.lower().replace(',', '.').replace(' ', '')
        
        for suffix in self.CURRENCY_SUFFIXES:
            text_lower = text_lower.replace(suffix, '')
        
        for pattern in self.PRICE_PATTERNS:
            match = re.search(pattern, text_lower)
            if match:
                try:
                    price_str = match.group(1).replace(',', '.')
                    price = float(price_str)
                    if 0.01 <= price <= 10000:
                        return price
                except ValueError:
                    continue
        
        return None
    
    def find_prices(self, ocr_results: List[Dict]) -> List[Dict]:
        """OCR sonuçlarından fiyatları filtreler."""
        prices = []
        for item in ocr_results:
            price = self.extract_price(item["text"])
            if price is not None:
                prices.append({
                    "text": item["text"],
                    "price": price,
                    "confidence": item["confidence"],
                    "center": item["center"],
                    "bbox_norm": item["bbox_norm"],
                })
        return prices


def create_ocr(**kwargs) -> ShelfOCR:
    """Factory function."""
    return ShelfOCR(**kwargs)