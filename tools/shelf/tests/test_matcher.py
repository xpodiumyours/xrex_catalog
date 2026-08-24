"""tools.shelf.tests.test_matcher - Unit tests for PriceProductMatcher"""

import pytest
from tools.shelf.matcher import PriceProductMatcher, create_matcher


class TestPriceProductMatcher:
    """Test spatial matching heuristics."""
    
    def setup_method(self):
        self.matcher = create_matcher(max_distance=0.15)
    
    def test_basic_match(self):
        """Single product, single price - should match."""
        products = [{
            "label": "bottle",
            "center": (0.5, 0.5),
            "bbox_norm": [0.4, 0.4, 0.6, 0.6],
        }]
        prices = [{
            "price": 45.90,
            "center": (0.5, 0.55),
            "text": "45.90 TL",
        }]
        
        matched = self.matcher.match(products, prices)
        
        assert len(matched) == 1
        assert matched[0].get("price") == 45.90
    
    def test_no_match_too_far(self):
        """Price too far from product - should not match."""
        products = [{
            "label": "bottle",
            "center": (0.1, 0.1),
        }]
        prices = [{
            "price": 45.90,
            "center": (0.9, 0.9),
        }]
        
        matched = self.matcher.match(products, prices)
        
        assert len(matched) == 1
        assert "price" not in matched[0]
    
    def test_multiple_products_one_price_each(self):
        """Two products, two prices - each should match closest."""
        products = [
            {"label": "bottle", "center": (0.2, 0.5)},
            {"label": "cup", "center": (0.8, 0.5)},
        ]
        prices = [
            {"price": 10.0, "center": (0.22, 0.52)},
            {"price": 20.0, "center": (0.78, 0.52)},
        ]
        
        matched = self.matcher.match(products, prices)
        
        assert matched[0].get("price") == 10.0
        assert matched[1].get("price") == 20.0
    
    def test_price_below_product_preferred(self):
        """Price below product should be preferred over price above."""
        products = [{
            "label": "bottle",
            "center": (0.5, 0.4),
        }]
        prices = [
            {"price": 10.0, "center": (0.5, 0.5)},  # below, dist=0.1
            {"price": 20.0, "center": (0.5, 0.3)},  # above, dist=0.1
        ]
        
        matched = self.matcher.match(products, prices)
        
        assert matched[0].get("price") == 10.0
    
    def test_horizontal_alignment_bonus(self):
        """Same row (horizontal alignment) should get bonus."""
        products = [
            {"label": "bottle", "center": (0.3, 0.5)},
            {"label": "cup", "center": (0.7, 0.5)},
        ]
        prices = [
            {"price": 10.0, "center": (0.32, 0.55)},  # aligned with first
            {"price": 20.0, "center": (0.72, 0.55)},  # aligned with second
        ]
        
        matched = self.matcher.match(products, prices)
        
        assert matched[0].get("price") == 10.0
        assert matched[1].get("price") == 20.0
    
    def test_one_price_shared_multiple_products(self):
        """One price can only match one product (greedy)."""
        products = [
            {"label": "bottle", "center": (0.4, 0.5)},
            {"label": "cup", "center": (0.6, 0.5)},
        ]
        prices = [
            {"price": 15.0, "center": (0.5, 0.55)},
        ]
        
        matched = self.matcher.match(products, prices)
        
        # Only one should get the price
        prices_assigned = [p.get("price") for p in matched if "price" in p]
        assert len(prices_assigned) == 1
        assert prices_assigned[0] == 15.0
    
    def test_empty_inputs(self):
        """Empty products or prices should return products unchanged."""
        assert self.matcher.match([], []) == []
        assert self.matcher.match([{"label": "test"}], []) == [{"label": "test"}]
        assert self.matcher.match([], [{"price": 10.0}]) == []
    
    def test_match_score_included(self):
        """Match score should be included in result."""
        products = [{"label": "bottle", "center": (0.5, 0.5)}]
        prices = [{"price": 45.90, "center": (0.5, 0.55)}]
        
        matched = self.matcher.match(products, prices)
        
        assert "match_score" in matched[0]
        assert isinstance(matched[0]["match_score"], float)
    
    def test_custom_weights(self):
        """Custom weights should affect matching."""
        # High vertical weight - strongly prefer price below
        matcher = create_matcher(
            max_distance=0.2,
            vertical_weight=0.8,
            horizontal_weight=0.1,
            distance_weight=0.1,
        )
        
        products = [{"label": "bottle", "center": (0.5, 0.4)}]
        prices = [
            {"price": 10.0, "center": (0.5, 0.6)},  # below
            {"price": 20.0, "center": (0.5, 0.2)},  # above, closer
        ]
        
        matched = matcher.match(products, prices)
        
        # Should prefer below even though above is closer
        assert matched[0].get("price") == 10.0


class TestMatcherEdgeCases:
    """Edge case tests."""
    
    def setup_method(self):
        self.matcher = create_matcher()
    
    def test_duplicate_price_texts(self):
        """Multiple prices with same text but different positions."""
        products = [
            {"label": "bottle", "center": (0.2, 0.5)},
            {"label": "cup", "center": (0.8, 0.5)},
        ]
        prices = [
            {"price": 10.0, "center": (0.22, 0.55), "text": "10.00 TL"},
            {"price": 10.0, "center": (0.78, 0.55), "text": "10.00 TL"},
        ]
        
        matched = self.matcher.match(products, prices)
        
        assert matched[0].get("price") == 10.0
        assert matched[1].get("price") == 10.0
    
    def test_price_on_product_center(self):
        """Price exactly at product center."""
        products = [{"label": "bottle", "center": (0.5, 0.5)}]
        prices = [{"price": 45.90, "center": (0.5, 0.5)}]
        
        matched = self.matcher.match(products, prices)
        
        assert matched[0].get("price") == 45.90
    
    def test_many_products_few_prices(self):
        """More products than prices."""
        products = [{"label": f"p{i}", "center": (i*0.1, 0.5)} for i in range(10)]
        prices = [{"price": 10.0, "center": (0.05, 0.55)}]
        
        matched = self.matcher.match(products, prices)
        
        prices_assigned = sum(1 for p in matched if "price" in p)
        assert prices_assigned == 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])