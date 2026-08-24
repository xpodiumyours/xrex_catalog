"""tools.shelf.exporter - Export Utilities (JSON, CSV, COCO, YOLO formats)"""

from typing import List, Dict, Any, Optional
from pathlib import Path
import json
import csv
from datetime import datetime


def export_json(
    products: List[Dict],
    output_path: str,
    metadata: Optional[Dict] = None,
    stats: Optional[Dict] = None,
) -> None:
    """Ürün listesini JSON olarak kaydet."""
    output = {
        "exported_at": datetime.now().isoformat(),
        "metadata": metadata or {},
        "stats": stats or {},
        "product_count": len(products),
        "products": products,
    }
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)


def export_csv(
    products: List[Dict],
    output_path: str,
    fields: Optional[List[str]] = None,
) -> None:
    """Ürün listesini CSV olarak kaydet."""
    if not products:
        return
    
    default_fields = [
        "label", "confidence", "price", "price_confidence",
        "bbox_x1", "bbox_y1", "bbox_x2", "bbox_y2",
        "center_x", "center_y",
    ]
    
    fields = fields or default_fields
    
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for p in products:
            row = {
                "label": p.get("label", ""),
                "confidence": p.get("confidence", ""),
                "price": p.get("price", ""),
                "price_confidence": p.get("price_confidence", ""),
                "bbox_x1": p.get("bbox", [0,0,0,0])[0] if p.get("bbox") else "",
                "bbox_y1": p.get("bbox", [0,0,0,0])[1] if p.get("bbox") else "",
                "bbox_x2": p.get("bbox", [0,0,0,0])[2] if p.get("bbox") else "",
                "bbox_y2": p.get("bbox", [0,0,0,0])[3] if p.get("bbox") else "",
                "center_x": p.get("center", [0,0])[0] if p.get("center") else "",
                "center_y": p.get("center", [0,0])[1] if p.get("center") else "",
            }
            writer.writerow({k: row.get(k, "") for k in fields})


def export_coco(
    products: List[Dict],
    output_path: str,
    image_info: Dict,
    categories: Optional[List[Dict]] = None,
) -> None:
    """COCO detection formatında export (labeling tool'lar için)."""
    if categories is None:
        # Unique labels from products
        labels = sorted(set(p["label"] for p in products))
        categories = [{"id": i+1, "name": l, "supercategory": "product"} for i, l in enumerate(labels)]
    
    label_to_id = {c["name"]: c["id"] for c in categories}
    
    annotations = []
    for i, p in enumerate(products):
        bbox = p.get("bbox", [0,0,0,0])
        x, y, x2, y2 = bbox
        w, h = x2 - x, y2 - y
        
        ann = {
            "id": i + 1,
            "image_id": image_info.get("id", 1),
            "category_id": label_to_id.get(p["label"], 1),
            "bbox": [x, y, w, h],
            "area": w * h,
            "iscrowd": 0,
            "score": p.get("confidence", 0),
        }
        if "price" in p:
            ann["attributes"] = {"price": p["price"]}
        annotations.append(ann)
    
    coco = {
        "info": {"description": "Shelf scan export", "date_created": datetime.now().isoformat()},
        "licenses": [],
        "images": [image_info],
        "categories": categories,
        "annotations": annotations,
    }
    
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(coco, f, ensure_ascii=False, indent=2)


def export_yolo(
    products: List[Dict],
    output_dir: str,
    image_name: str,
    img_width: int,
    img_height: int,
    label_map: Optional[Dict[str, int]] = None,
) -> None:
    """YOLO label formatında export (training için)."""
    if label_map is None:
        labels = sorted(set(p["label"] for p in products))
        label_map = {l: i for i, l in enumerate(labels)}
    
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    label_path = Path(output_dir) / f"{Path(image_name).stem}.txt"
    
    lines = []
    for p in products:
        bbox = p.get("bbox", [0,0,0,0])
        x, y, x2, y2 = bbox
        
        # YOLO format: class_id x_center y_center width height (normalized)
        xc = (x + x2) / 2 / img_width
        yc = (y + y2) / 2 / img_height
        w = (x2 - x) / img_width
        h = (y2 - y) / img_height
        
        class_id = label_map.get(p["label"], 0)
        lines.append(f"{class_id} {xc:.6f} {yc:.6f} {w:.6f} {h:.6f}")
    
    with open(label_path, "w") as f:
        f.write("\n".join(lines))
    
    # Save label map
    map_path = Path(output_dir) / "labels.txt"
    with open(map_path, "w") as f:
        for label, idx in sorted(label_map.items(), key=lambda x: x[1]):
            f.write(f"{idx}: {label}\n")


def export_all(
    result: Dict,
    output_dir: str,
    formats: List[str] = ["json", "csv"],
) -> Dict[str, str]:
    """Tüm formatlarda export et."""
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    exported = {}
    products = result.get("products", [])
    metadata = result.get("metadata", {})
    stats = result.get("stats", {})
    
    if "json" in formats:
        path = str(Path(output_dir) / "result.json")
        export_json(products, path, metadata, stats)
        exported["json"] = path
    
    if "csv" in formats:
        path = str(Path(output_dir) / "result.csv")
        export_csv(products, path)
        exported["csv"] = path
    
    if "coco" in formats:
        path = str(Path(output_dir) / "result_coco.json")
        image_info = {
            "id": 1,
            "file_name": metadata.get("source", "unknown"),
            "width": metadata.get("image_shape", [640, 640])[1],
            "height": metadata.get("image_shape", [640, 640])[0],
        }
        export_coco(products, path, image_info)
        exported["coco"] = path
    
    if "yolo" in formats:
        path = str(Path(output_dir) / "labels")
        export_yolo(
            products, path,
            metadata.get("source", "image.jpg"),
            metadata.get("image_shape", [640, 640])[1],
            metadata.get("image_shape", [640, 640])[0],
        )
        exported["yolo"] = path
    
    return exported