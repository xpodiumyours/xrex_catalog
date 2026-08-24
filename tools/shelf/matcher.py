"""tools.shelf.matcher - Spatial Price-Product Matching Heuristics

Geometric matching between product detections and price tag OCR results.
Uses weighted scoring: distance, horizontal alignment, vertical preference.
"""

from typing import List, Dict, Any, Optional, Tuple
import math


class PriceProductMatcher:
    """Fiyat-ürün eşleştirme motoru."""
    
    def __init__(
        self,
        max_distance: float = 0.15,           # Normalized max center distance
        horizontal_weight: float = 0.30,      # Same shelf row bonus
        vertical_weight: float = 0.20,        # Price below product preference
        distance_weight: float = 0.50,        # Center distance penalty
        vertical_preference: bool = True,     # Price usually below product
    ):
        self.max_distance = max_distance
        self.horizontal_weight = horizontal_weight
        self.vertical_weight = vertical_weight
        self.distance_weight = distance_weight
        self.vertical_preference = vertical_preference
    
    def match(
        self,
        products: List[Dict],
        prices: List[Dict],
    ) -> List[Dict]:
        """
        Her ürün için en uygun fiyat etiketini bulur.
        
        Args:
            products: [{bbox_norm, center, class_name, conf, ...}, ...]
            prices: [{center, price, confidence, text, bbox_norm, ...}, ...]
            
        Returns:
            Matched products with price field added
        """
        if not products or not prices:
            return products
        
        matched = []
        used_prices = set()
        
        for prod in products:
            px, py = prod["center"]
            best_price = None
            best_score = float('inf')
            best_idx = -1
            
            for idx, price in enumerate(prices):
                if idx in used_prices:
                    continue
                
                qx, qy = price["center"]
                
                # Normalized Euclidean distance
                dist = math.hypot(px - qx, py - qy)
                
                if dist > self.max_distance:
                    continue
                
                # Horizontal alignment (same shelf row)
                h_align = 1.0 - min(abs(px - qx) / 0.3, 1.0)
                
                # Vertical preference (price below product)
                v_pref = 1.0
                if self.vertical_preference:
                    v_pref = 1.0 if qy > py else 0.5
                
                # Weighted score (lower is better)
                score = (
                    dist * self.distance_weight
                    - h_align * self.horizontal_weight
                    - v_pref * self.vertical_weight
                )
                
                if score < best_score:
                    best_score = score
                    best_price = price
                    best_idx = idx
            
            if best_price and best_idx >= 0:
                prod = prod.copy()  # Don't mutate original
                prod["price"] = best_price["price"]
                prod["price_text"] = best_price.get("text", "")
                prod["price_confidence"] = best_price.get("confidence", 0.0)
                prod["match_score"] = best_score
                used_prices.add(best_idx)
            
            matched.append(prod)
        
        return matched
    
    def match_hungarian(
        self,
        products: List[Dict],
        prices: List[Dict],
    ) -> List[Dict]:
        """
        Optimal assignment using Hungarian algorithm (scipy.optimize).
        Better for crowded shelves where greedy fails.
        """
        try:
            from scipy.optimize import linear_sum_assignment
        except ImportError:
            # Fallback to greedy
            return self.match(products, prices)
        
        if not products or not prices:
            return products
        
        # Cost matrix
        n_prod = len(products)
        n_price = len(prices)
        cost_matrix = [[float('inf')] * n_price for _ in range(n_prod)]
        
        for i, prod in enumerate(products):
            px, py = prod["center"]
            for j, price in enumerate(prices):
                qx, qy = price["center"]
                dist = math.hypot(px - qx, py - qy)
                
                if dist <= self.max_distance:
                    h_align = 1.0 - min(abs(px - qx) / 0.3, 1.0)
                    v_pref = 1.0 if (qy > py) else 0.5
                    cost = dist * self.distance_weight - h_align * self.horizontal_weight - v_pref * self.vertical_weight
                    cost_matrix[i][j] = cost
        
        # Solve assignment
        row_ind, col_ind = linear_sum_assignment(cost_matrix)
        
        matched = []
        used_prices = set(col_ind)
        
        for i, prod in enumerate(products):
            prod_copy = prod.copy()
            if i in row_ind:
                j = col_ind[list(row_ind).index(i)]
                if cost_matrix[i][j] != float('inf'):
                    best_price = prices[j]
                    prod_copy["price"] = best_price["price"]
                    prod_copy["price_text"] = best_price.get("text", "")
                    prod_copy["price_confidence"] = best_price.get("confidence", 0.0)
                    prod_copy["match_score"] = cost_matrix[i][j]
                else:
                    prod_copy["price"] = None
            else:
                prod_copy["price"] = None
            matched.append(prod_copy)
        
        return matched


def iou(box1: List[float], box2: List[float]) -> float:
    """Normalized bbox IOU. box: [x1, y1, x2, y2] in [0,1]."""
    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])
    
    if x2 <= x1 or y2 <= y1:
        return 0.0
    
    inter = (x2 - x1) * (y2 - y1)
    area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
    area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])
    
    return inter / (area1 + area2 - inter)


def create_matcher(**kwargs) -> PriceProductMatcher:
    """Factory function."""
    return PriceProductMatcher(**kwargs)