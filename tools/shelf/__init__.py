"""tools.shelf - Market Rafı Tarama Pipeline ($0 Local-First)

Public API:
    scan_shelf(image_path, **kwargs) -> List[Dict]
    ShelfScanner class for advanced usage

Pipeline: Detection (YOLOv8n) -> Crop -> OCR (PaddleOCR) -> Price Filter -> Spatial Match -> Export
"""

from .parser import scan_shelf, ShelfScanner

__all__ = ["scan_shelf", "ShelfScanner"]
__version__ = "0.1.0-shelf"