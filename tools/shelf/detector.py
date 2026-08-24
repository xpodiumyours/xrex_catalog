"""tools.shelf.detector - YOLOv8n Object Detection Wrapper

COCO pre-trained classes relevant for retail:
    39: bottle, 40: wine glass, 41: cup, 42: fork, 43: knife, 44: spoon,
    45: bowl, 46: banana, 47: apple, 48: sandwich, 49: orange,
    50: broccoli, 51: carrot, 52: hot dog, 53: pizza, 54: donut, 55: cake,
    56: chair, 57: couch, 58: potted plant, 59: bed, 60: dining table,
    61: toilet, 62: tv, 63: laptop, 64: mouse, 65: remote, 66: keyboard,
    67: cell phone, 68: microwave, 69: oven, 70: toaster, 71: sink,
    72: refrigerator, 73: book, 74: clock, 75: vase, 76: scissors,
    77: teddy bear, 78: hair drier, 79: toothbrush

Market-specific classes need fine-tuning (see fine_tune_guide.md)
"""

from pathlib import Path
from typing import List, Dict, Any, Optional
import cv2
import numpy as np

try:
    from ultralytics import YOLO
except ImportError:
    YOLO = None


class ShelfDetector:
    """YOLOv8n tabanlı raf ürün dedektörü."""
    
    # COCO sınıflarından market için ilgili olanlar
    RETAIL_CLASSES = {
        39: "bottle", 40: "wine_glass", 41: "cup", 42: "fork", 43: "knife",
        44: "spoon", 45: "bowl", 46: "banana", 47: "apple", 48: "sandwich",
        49: "orange", 50: "broccoli", 51: "carrot", 52: "hot_dog", 53: "pizza",
        54: "donut", 55: "cake", 56: "chair", 57: "couch", 58: "potted_plant",
        59: "bed", 60: "dining_table", 61: "toilet", 62: "tv", 63: "laptop",
        64: "mouse", 65: "remote", 66: "keyboard", 67: "cell_phone",
        68: "microwave", 69: "oven", 70: "toaster", 71: "sink",
        72: "refrigerator", 73: "book", 74: "clock", 75: "vase",
        76: "scissors", 77: "teddy_bear", 78: "hair_drier", 79: "toothbrush",
    }
    
    def __init__(
        self,
        model_path: Optional[str] = None,
        conf_thresh: float = 0.25,
        iou_thresh: float = 0.45,
        device: str = "cpu",
        imgsz: int = 640,
        retail_only: bool = False,  # If True, filter to retail-relevant COCO classes
    ):
        if YOLO is None:
            raise RuntimeError("ultralytics not installed. Run: pip install ultralytics")
        
        self.conf_thresh = conf_thresh
        self.iou_thresh = iou_thresh
        self.device = device
        self.imgsz = imgsz
        self.retail_only = retail_only
        
        # Model yükle
        if model_path and Path(model_path).exists():
            self.model = YOLO(model_path)
        else:
            # COCO pre-trained
            self.model = YOLO("yolov8n.pt")
        
        self.model.to(device)
        self.names = self.model.names
    
    def predict(self, image: np.ndarray) -> List[Dict[str, Any]]:
        """
        Görüntüden nesne tespiti yapar.
        
        Args:
            image: BGR formatında numpy array (cv2.imread output)
            
        Returns:
            List[Dict]: Her dict -> {bbox, class_id, class_name, conf, center}
                bbox: [x1, y1, x2, y2] (piksel koordinatları)
                center: (cx, cy) normalized [0,1]
        """
        h, w = image.shape[:2]
        
        # Classes to filter
        classes = list(self.RETAIL_CLASSES.keys()) if self.retail_only else None
        
        results = self.model.predict(
            source=image,
            conf=self.conf_thresh,
            iou=self.iou_thresh,
            imgsz=self.imgsz,
            device=self.device,
            verbose=False,
            classes=classes,
        )[0]
        
        detections = []
        for box in results.boxes:
            x1, y1, x2, y2 = map(int, box.xyxy[0].cpu().numpy())
            cls_id = int(box.cls[0].cpu().numpy())
            conf = float(box.conf[0].cpu().numpy())
            
            # Use COCO name if not in retail map
            class_name = self.RETAIL_CLASSES.get(cls_id, self.names.get(cls_id, f"class_{cls_id}"))
            
            cx = (x1 + x2) / 2 / w
            cy = (y1 + y2) / 2 / h
            
            detections.append({
                "bbox": [x1, y1, x2, y2],
                "bbox_norm": [x1/w, y1/h, x2/w, y2/h],
                "class_id": cls_id,
                "class_name": class_name,
                "conf": conf,
                "center": (cx, cy),
                "area": (x2 - x1) * (y2 - y1),
            })
        
        return detections
    
    def predict_path(self, image_path: str) -> List[Dict[str, Any]]:
        """Dosya yolu ile tahmin."""
        image = cv2.imread(image_path)
        if image is None:
            raise FileNotFoundError(f"Image not found: {image_path}")
        return self.predict(image)
    
    def export_onnx(self, output_path: str, half: bool = False) -> str:
        """Modeli ONNX formatına export et."""
        return self.model.export(
            format="onnx",
            imgsz=self.imgsz,
            half=half,
            opset=12,
            simplify=True,
        )
    
    def export_ncnn(self, output_dir: str) -> str:
        """Modeli NCNN formatına export et (mobile/embedded)."""
        return self.model.export(format="ncnn", imgsz=self.imgsz)
    
    def export_tflite(self, output_path: str, int8: bool = False) -> str:
        """Modeli TFLite formatına export et."""
        return self.model.export(format="tflite", imgsz=self.imgsz, int8=int8)


def create_detector(**kwargs) -> ShelfDetector:
    """Factory function for easy instantiation."""
    return ShelfDetector(**kwargs)