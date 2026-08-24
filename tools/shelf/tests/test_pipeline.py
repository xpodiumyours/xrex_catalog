"""tools.shelf.tests.test_pipeline - Integration tests for full shelf scanning pipeline"""

import pytest
import json
import tempfile
import os
from pathlib import Path
from tools.shelf import scan_shelf, ShelfScanner
from tools.shelf.exporter import export_json, export_csv


class TestPipelineIntegration:
    """Integration tests for the full pipeline."""
    
    def setup_method(self):
        self.scanner = ShelfScanner(conf_thresh=0.1, device='cpu', retail_only=False)
    
    def test_scan_returns_list(self):
        """scan_shelf should return a list."""
        result = scan_shelf('test_shelf.jpg', conf_thresh=0.1, device='cpu', retail_only=False)
        assert isinstance(result, list)
    
    def test_scan_result_structure(self):
        """Each product should have required fields."""
        result = scan_shelf('test_shelf.jpg', conf_thresh=0.1, device='cpu', retail_only=False)
        for product in result:
            assert "label" in product
            assert "confidence" in product
            assert "bbox" in product
            assert "bbox_norm" in product
            assert "center" in product
    
    def test_scanner_class_scan(self):
        """ShelfScanner.scan should return ScanResult."""
        result = self.scanner.scan('test_shelf.jpg')
        assert hasattr(result, 'products')
        assert hasattr(result, 'stats')
        assert hasattr(result, 'metadata')
        assert isinstance(result.products, list)
        assert isinstance(result.stats, dict)
        assert 'total_time_ms' in result.stats
    
    def test_scanner_export_json(self):
        """ShelfScanner.export_json should write valid JSON."""
        result = self.scanner.scan('test_shelf.jpg')
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            temp_path = f.name
        
        try:
            self.scanner.export_json(result, temp_path)
            
            with open(temp_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            assert 'metadata' in data
            assert 'stats' in data
            assert 'products' in data
            assert isinstance(data['products'], list)
        finally:
            os.unlink(temp_path)
    
    def test_scanner_export_csv(self):
        """ShelfScanner.export_csv should write valid CSV."""
        # Create a result with mock products
        from tools.shelf.parser import ScanResult
        result = ScanResult(
            products=[
                {"label": "bottle", "confidence": 0.9, "price": 45.90, "bbox": [10, 10, 50, 50], "center": [0.1, 0.1]},
            ],
            stats={"total_time_ms": 100},
            metadata={"source": "test"}
        )
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False) as f:
            temp_path = f.name
        
        try:
            self.scanner.export_csv(result, temp_path)
            
            with open(temp_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            assert 'label,confidence,price' in content
            assert 'bottle' in content
        finally:
            os.unlink(temp_path)
    
    def test_confidence_filtering(self):
        """Higher conf_thresh should return fewer detections."""
        result_low = scan_shelf('test_shelf.jpg', conf_thresh=0.01, device='cpu', retail_only=False)
        result_high = scan_shelf('test_shelf.jpg', conf_thresh=0.9, device='cpu', retail_only=False)
        
        assert len(result_high) <= len(result_low)
    
    def test_retail_only_filter(self):
        """retail_only=True should filter classes."""
        result_all = scan_shelf('test_shelf.jpg', conf_thresh=0.1, device='cpu', retail_only=False)
        result_retail = scan_shelf('test_shelf.jpg', conf_thresh=0.1, device='cpu', retail_only=True)
        
        # retail_only should return same or fewer (depending on detections)
        assert len(result_retail) <= len(result_all)
    
    def test_stats_contains_timing(self):
        """Stats should contain timing breakdown."""
        result = self.scanner.scan('test_shelf.jpg')
        stats = result.stats
        
        assert 'total_time_ms' in stats
        assert 'detection_time_ms' in stats
        assert 'ocr_time_ms' in stats
        assert 'match_time_ms' in stats
        assert 'num_detections' in stats
        assert 'num_products' in stats
    
    def test_metadata_contains_shape(self):
        """Metadata should contain image shape."""
        result = self.scanner.scan('test_shelf.jpg')
        meta = result.metadata
        
        assert 'image_shape' in meta
        assert len(meta['image_shape']) == 2


class TestExporter:
    """Test export functions."""
    
    def test_export_json(self):
        """export_json should write valid JSON with all fields."""
        products = [
            {"label": "bottle", "confidence": 0.9, "price": 45.90, "bbox": [10, 10, 50, 50]},
            {"label": "cup", "confidence": 0.8, "bbox": [60, 10, 100, 50]},
        ]
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            temp_path = f.name
        
        try:
            export_json(products, temp_path, metadata={"test": True}, stats={"count": 2})
            
            with open(temp_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            assert data['product_count'] == 2
            assert data['metadata']['test'] is True
            assert data['stats']['count'] == 2
            assert len(data['products']) == 2
            assert data['products'][0]['price'] == 45.90
        finally:
            os.unlink(temp_path)
    
    def test_export_csv(self):
        """export_csv should write valid CSV."""
        products = [
            {"label": "bottle", "confidence": 0.9, "price": 45.90, "bbox": [10, 10, 50, 50], "center": [0.1, 0.1]},
        ]
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.csv', delete=False) as f:
            temp_path = f.name
        
        try:
            export_csv(products, temp_path)
            
            with open(temp_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            assert 'bottle' in content
            assert '45.9' in content  # float formatting
        finally:
            os.unlink(temp_path)
    
    def test_export_coco(self):
        """export_coco should write valid COCO format."""
        from tools.shelf.exporter import export_coco
        
        products = [
            {"label": "bottle", "confidence": 0.9, "bbox": [10, 10, 50, 50]},
        ]
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            temp_path = f.name
        
        try:
            image_info = {"id": 1, "file_name": "test.jpg", "width": 640, "height": 480}
            export_coco(products, temp_path, image_info)
            
            with open(temp_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            assert 'images' in data
            assert 'annotations' in data
            assert 'categories' in data
            assert len(data['annotations']) == 1
        finally:
            os.unlink(temp_path)
    
    def test_export_yolo(self):
        """export_yolo should write YOLO label format."""
        from tools.shelf.exporter import export_yolo
        
        products = [
            {"label": "bottle", "confidence": 0.9, "bbox": [100, 100, 200, 200]},
        ]
        
        with tempfile.TemporaryDirectory() as temp_dir:
            export_yolo(products, temp_dir, "test.jpg", 640, 480)
            
            label_file = Path(temp_dir) / "test.txt"
            assert label_file.exists()
            
            content = label_file.read_text()
            assert '0' in content  # class_id
            
            map_file = Path(temp_dir) / "labels.txt"
            assert map_file.exists()


class TestMatcherIntegration:
    """Test matcher with realistic scenarios."""
    
    def test_match_products_with_prices(self):
        """Full matching workflow."""
        from tools.shelf.matcher import create_matcher
        
        matcher = create_matcher(max_distance=0.15)
        
        products = [
            {"label": "bottle", "center": (0.2, 0.5), "confidence": 0.9},
            {"label": "cup", "center": (0.5, 0.5), "confidence": 0.8},
            {"label": "box", "center": (0.8, 0.5), "confidence": 0.7},
        ]
        prices = [
            {"price": 15.50, "center": (0.22, 0.55), "text": "15.50 TL", "confidence": 0.95},
            {"price": 8.90, "center": (0.52, 0.55), "text": "8.90", "confidence": 0.9},
            {"price": 25.00, "center": (0.78, 0.55), "text": "25.00", "confidence": 0.85},
        ]
        
        matched = matcher.match(products, prices)
        
        assert len(matched) == 3
        prices_found = [p.get("price") for p in matched if "price" in p]
        assert 15.50 in prices_found
        assert 8.90 in prices_found
        assert 25.00 in prices_found
    
    def test_unmatched_products_keep_original(self):
        """Products without matching price should remain unchanged."""
        from tools.shelf.matcher import create_matcher
        
        matcher = create_matcher(max_distance=0.15)
        
        products = [
            {"label": "bottle", "center": (0.2, 0.5)},
            {"label": "cup", "center": (0.8, 0.5)},
        ]
        prices = [
            {"price": 15.50, "center": (0.22, 0.55)},
        ]
        
        matched = matcher.match(products, prices)
        
        # First product should have price, second should not
        assert matched[0].get("price") == 15.50
        assert "price" not in matched[1]


class TestErrorHandling:
    """Test error handling and edge cases."""
    
    def test_nonexistent_image(self):
        """Non-existent image should raise FileNotFoundError."""
        with pytest.raises(FileNotFoundError):
            scan_shelf('nonexistent.jpg', conf_thresh=0.1, device='cpu')
    
    def test_empty_image_array(self):
        """Empty numpy array should be handled gracefully."""
        import numpy as np
        empty_img = np.zeros((100, 100, 3), dtype=np.uint8)
        
        result = scan_shelf(empty_img, conf_thresh=0.1, device='cpu', retail_only=False)
        assert isinstance(result, list)
    
    def test_invalid_conf_threshold(self):
        """conf_thresh > 1.0 should raise ValueError (Ultralytics validation)."""
        with pytest.raises(ValueError):
            scan_shelf('test_shelf.jpg', conf_thresh=1.5, device='cpu', retail_only=False)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])