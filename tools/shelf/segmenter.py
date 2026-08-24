"""tools.shelf.segmenter - MobileSAM Integration (Optional)

Segmentation for precise product boundaries.
Lazy-loaded, only used when explicitly enabled.
"""

from typing import List, Dict, Any, Optional
import cv2
import numpy as np

try:
    import torch
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False


class MobileSAMSegmenter:
    """MobileSAM tabanlı segmentasyon (opsiyonel)."""
    
    def __init__(
        self,
        model_path: str = "mobile_sam.pt",
        device: str = "cpu",
        points_per_side: int = 32,
    ):
        if not TORCH_AVAILABLE:
            raise RuntimeError("PyTorch not installed. Run: pip install torch")
        
        self.device = device
        self.points_per_side = points_per_side
        
        # Load model
        try:
            from mobile_sam import sam_model_registry, SamAutomaticMaskGenerator
            sam = sam_model_registry["vit_t"](checkpoint=model_path)
            sam.to(device=device)
            self.mask_generator = SamAutomaticMaskGenerator(
                model=sam,
                points_per_side=points_per_side,
                pred_iou_thresh=0.88,
                stability_score_thresh=0.95,
                crop_n_layers=1,
                crop_n_points_downscale_factor=2,
                min_mask_region_area=100,
            )
        except ImportError:
            raise RuntimeError("mobile_sam not installed. Run: pip install mobile_sam")
    
    def segment(self, image: np.ndarray) -> List[Dict[str, Any]]:
        """Görüntüyü segmentlere ayır."""
        # MobileSAM expects RGB
        if image.shape[2] == 3:
            image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        else:
            image_rgb = image
        
        masks = self.mask_generator.generate(image_rgb)
        
        results = []
        for mask_data in masks:
            segmentation = mask_data["segmentation"]
            bbox = mask_data["bbox"]  # [x, y, w, h]
            area = mask_data["area"]
            
            # Convert to polygon
            contours, _ = cv2.findContours(
                segmentation.astype(np.uint8),
                cv2.RETR_EXTERNAL,
                cv2.CHAIN_APPROX_SIMPLE
            )
            
            polygons = []
            for contour in contours:
                if len(contour) >= 3:
                    polygon = contour.squeeze().tolist()
                    if isinstance(polygon[0], list):
                        polygons.append(polygon)
            
            x, y, w, h = bbox
            results.append({
                "bbox": [x, y, x + w, y + h],
                "bbox_norm": [x/image.shape[1], y/image.shape[0], 
                             (x+w)/image.shape[1], (y+h)/image.shape[0]],
                "area": area,
                "polygons": polygons,
                "stability_score": mask_data.get("stability_score", 0),
                "predicted_iou": mask_data.get("predicted_iou", 0),
            })
        
        return results
    
    def segment_with_boxes(self, image: np.ndarray, boxes: List[List[float]]) -> List[Dict]:
        """Verilen box'lar için maskeler üret (prompt-based)."""
        try:
            from mobile_sam import sam_model_registry, SamPredictor
        except ImportError:
            return []
        
        predictor = SamPredictor(self.mask_generator.model)
        predictor.set_image(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        
        results = []
        for box in boxes:
            x1, y1, x2, y2 = box
            input_box = np.array([x1, y1, x2, y2])
            
            masks, scores, logits = predictor.predict(
                box=input_box[None, :],
                multimask_output=True,
            )
            
            # Best mask
            best_idx = np.argmax(scores)
            mask = masks[best_idx]
            
            # Convert to polygon
            contours, _ = cv2.findContours(
                mask.astype(np.uint8),
                cv2.RETR_EXTERNAL,
                cv2.CHAIN_APPROX_SIMPLE
            )
            
            polygons = []
            for contour in contours:
                if len(contour) >= 3:
                    polygon = contour.squeeze().tolist()
                    if isinstance(polygon[0], list):
                        polygons.append(polygon)
            
            results.append({
                "mask": mask,
                "score": float(scores[best_idx]),
                "polygons": polygons,
            })
        
        return results


def create_segmenter(model_path: str = "mobile_sam.pt", device: str = "cpu") -> Optional[MobileSAMSegmenter]:
    """Factory function - returns None if dependencies not available."""
    if not TORCH_AVAILABLE:
        return None
    try:
        return MobileSAMSegmenter(model_path, device)
    except Exception:
        return None


def get_segmenter() -> Optional[MobileSAMSegmenter]:
    """Global singleton segmenter (lazy load)."""
    if not hasattr(get_segmenter, "_instance"):
        get_segmenter._instance = create_segmenter()
    return get_segmenter._instance