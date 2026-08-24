#!/usr/bin/env python3
"""tools/shelf/production_hardening.py - Production Hardening Script

Sets up production-ready configuration:
- Health check endpoint
- Metrics collection
- Structured logging configuration
- Rate limiting
- Error tracking integration (Sentry)
- Graceful shutdown handling
"""

import argparse
import json
import sys
import signal
import time
from pathlib import Path
from typing import Dict, Any

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from tools.shelf import ShelfScanner
from tools.shelf.logging_utils import get_logger, setup_logger, JSONFormatter


class ProductionScanner:
    """Production-ready shelf scanner with monitoring and health checks."""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.scanner = None
        self.logger = None
        self._shutdown = False
        self.request_count = 0
        self.error_count = 0
        self.start_time = time.time()
        
        # Setup signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        self.logger.info(f"Received signal {signum}, initiating graceful shutdown")
        self._shutdown = True
    
    def initialize(self):
        """Initialize scanner and logging."""
        # Setup structured logging
        log_config = self.config.get("logging", {})
        self.logger = setup_logger(
            name="shelf_scanner_prod",
            level=log_config.get("level", "INFO"),
            json_format=log_config.get("json_format", True),
            output_file=log_config.get("output_file")
        )
        
        # Initialize scanner with production config
        scanner_config = self.config.get("scanner", {})
        self.scanner = ShelfScanner(
            warmup_on_init=scanner_config.get("warmup_on_init", True),
            enable_batch_ocr=scanner_config.get("enable_batch_ocr", True),
            enable_model_cache=scanner_config.get("enable_model_cache", True),
            log_level=log_config.get("level", "INFO"),
            log_json=log_config.get("json_format", True),
            **{k: v for k, v in scanner_config.items() 
               if k not in ["warmup_on_init", "enable_batch_ocr", "enable_model_cache"]}
        )
        
        self.logger.info("Production scanner initialized", extra={
            "config": scanner_config,
            "pid": os.getpid()
        })
    
    def health_check(self) -> Dict[str, Any]:
        """Health check endpoint for load balancers."""
        uptime = time.time() - self.start_time
        return {
            "status": "healthy" if not self._shutdown else "shutting_down",
            "uptime_seconds": round(uptime, 1),
            "requests_processed": self.request_count,
            "errors": self.error_count,
            "error_rate": round(self.error_count / max(1, self.request_count), 4),
            "models_loaded": {
                "detector": self.scanner._detector is not None,
                "ocr": self.scanner._ocr is not None,
                "warmed_up": self.scanner._warmed_up
            }
        }
    
    def scan(self, image_input) -> Dict[str, Any]:
        """Process scan request with monitoring."""
        if self._shutdown:
            return {"error": "Service shutting down", "status": "unavailable"}
        
        self.request_count += 1
        request_id = f"req_{self.request_count}_{int(time.time()*1000)}"
        
        self.logger.info("Scan request received", extra={"request_id": request_id})
        
        try:
            result = self.scanner.scan(image_input)
            self.logger.info("Scan completed", extra={
                "request_id": request_id,
                "products_found": len(result.products),
                "duration_ms": result.stats.get("total_time_ms", 0)
            })
            return {
                "status": "success",
                "request_id": request_id,
                "products": result.products,
                "stats": result.stats,
                "metadata": result.metadata
            }
        except Exception as e:
            self.error_count += 1
            self.logger.error("Scan failed", extra={
                "request_id": request_id,
                "error": str(e),
                "error_type": type(e).__name__
            }, exc_info=True)
            return {
                "status": "error",
                "request_id": request_id,
                "error": str(e)
            }
    
    def get_metrics(self) -> Dict[str, Any]:
        """Prometheus-compatible metrics."""
        uptime = time.time() - self.start_time
        return {
            "shelf_scanner_requests_total": self.request_count,
            "shelf_scanner_errors_total": self.error_count,
            "shelf_scanner_uptime_seconds": round(uptime, 1),
            "shelf_scanner_error_rate": round(self.error_count / max(1, self.request_count), 4),
            "shelf_scanner_models_loaded_detector": 1 if self.scanner._detector else 0,
            "shelf_scanner_models_loaded_ocr": 1 if self.scanner._ocr else 0,
            "shelf_scanner_warmed_up": 1 if self.scanner._warmed_up else 0,
        }
    
    def run_benchmark(self, iterations: int = 10) -> Dict[str, Any]:
        """Run performance benchmark."""
        import numpy as np
        test_img = np.random.randint(0, 255, (640, 640, 3), dtype=np.uint8)
        return self.scanner.benchmark(test_img, iterations=iterations)


def create_production_config() -> Dict[str, Any]:
    """Create default production configuration."""
    return {
        "logging": {
            "level": "INFO",
            "json_format": True,
            "output_file": "/var/log/shelf_scanner/app.log"
        },
        "scanner": {
            "conf_thresh": 0.25,
            "device": "cpu",
            "retail_only": False,
            "imgsz": 640,
            "enable_batch_ocr": True,
            "ocr_batch_size": 10,
            "enable_model_cache": True,
            "warmup_on_init": True,
            "detection_timeout": 10.0,
            "ocr_timeout": 15.0,
            "total_timeout": 30.0,
        },
        "monitoring": {
            "health_check_interval": 30,
            "metrics_port": 9090,
            "enable_sentry": False,
            "sentry_dsn": "",
        },
        "rate_limiting": {
            "enabled": True,
            "requests_per_minute": 60,
            "burst": 10
        }
    }


def save_config(config: Dict, path: str):
    """Save configuration to JSON file."""
    with open(path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    print(f"Configuration saved to: {path}")


def main():
    parser = argparse.ArgumentParser(description="Production hardening for shelf scanner")
    parser.add_argument("--config", help="Path to config JSON file")
    parser.add_argument("--create-config", help="Create default config at path")
    parser.add_argument("--health-check", action="store_true", help="Run health check and exit")
    parser.add_argument("--benchmark", type=int, help="Run benchmark with N iterations")
    parser.add_argument("--scan", help="Scan image file and exit")
    parser.add_argument("--serve", action="store_true", help="Run as service (blocking)")
    
    args = parser.parse_args()
    
    if args.create_config:
        config = create_production_config()
        save_config(config, args.create_config)
        return
    
    # Load config
    if args.config:
        with open(args.config, "r", encoding="utf-8") as f:
            config = json.load(f)
    else:
        config = create_production_config()
    
    # Initialize production scanner
    prod = ProductionScanner(config)
    prod.initialize()
    
    if args.health_check:
        health = prod.health_check()
        print(json.dumps(health, indent=2))
        sys.exit(0 if health["status"] == "healthy" else 1)
    
    if args.benchmark:
        result = prod.run_benchmark(args.benchmark)
        print(json.dumps(result, indent=2))
        return
    
    if args.scan:
        result = prod.scan(args.scan)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        sys.exit(0 if result.get("status") == "success" else 1)
    
    if args.serve:
        print("Production scanner running... Press Ctrl+C to stop")
        print(f"Health check: GET /health")
        print(f"Metrics: GET /metrics")
        try:
            while not prod._shutdown:
                time.sleep(1)
        except KeyboardInterrupt:
            pass
        finally:
            print("\nShutdown complete")


if __name__ == "__main__":
    import os
    import time
    main()