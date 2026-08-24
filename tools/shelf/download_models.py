#!/usr/bin/env python3
"""tools/shelf/download_models.py - Model İndirme Scripti

Gerekli modelleri indirir ve tools/shelf/models/ klasörüne kaydeder.
"""

import os
import sys
from pathlib import Path
import urllib.request
import hashlib

MODELS_DIR = Path(__file__).parent / "models"
MODELS_DIR.mkdir(exist_ok=True)

MODELS = {
    "yolov8n.pt": {
        "url": "https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.pt",
        "sha256": "a1b2c3d4e5f6...",  # Güncellenecek
        "description": "YOLOv8n COCO pre-trained (6MB)",
    },
    "mobile_sam.pt": {
        "url": "https://github.com/ChaoningZhang/MobileSAM/raw/master/weights/mobile_sam.pt",
        "sha256": "f6e5d4c3b2a1...",  # Güncellenecek
        "description": "MobileSAM ViT-Tiny (10MB)",
    },
}


def download_file(url: str, dest: Path, expected_sha256: str = None) -> bool:
    """Dosya indirir ve SHA256 doğrulaması yapar."""
    print(f"İndiriliyor: {url}")
    print(f"  -> {dest}")
    
    try:
        urllib.request.urlretrieve(url, dest)
        print(f"  ✓ Tamamlandı")
        
        if expected_sha256 and expected_sha256 != "a1b2c3d4e5f6...":
            print(f"  SHA256 doğrulanıyor...")
            with open(dest, "rb") as f:
                actual = hashlib.sha256(f.read()).hexdigest()
            if actual != expected_sha256:
                print(f"  ✗ SHA256 mismatch!")
                print(f"    Expected: {expected_sha256}")
                print(f"    Actual:   {actual}")
                dest.unlink()
                return False
            print(f"  ✓ SHA256 doğrulandı")
        
        return True
    except Exception as e:
        print(f"  ✗ Hata: {e}")
        if dest.exists():
            dest.unlink()
        return False


def main():
    print("=" * 60)
    print("Shelf Scanner Model İndirici")
    print("=" * 60)
    
    success = True
    for name, info in MODELS.items():
        dest = MODELS_DIR / name
        
        if dest.exists():
            print(f"\n{name} zaten mevcut, atlanıyor...")
            continue
        
        print(f"\n{info['description']}")
        ok = download_file(info["url"], dest, info.get("sha256"))
        if not ok:
            success = False
    
    print("\n" + "=" * 60)
    if success:
        print("✓ Tüm modeller başarıyla indirildi!")
        print(f"  Konum: {MODELS_DIR}")
    else:
        print("✗ Bazı modeller indirilemedi.")
        sys.exit(1)


if __name__ == "__main__":
    main()