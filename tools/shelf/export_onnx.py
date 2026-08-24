#!/usr/bin/env python3
"""tools/shelf/export_onnx.py - ONNX Export Script

YOLOv8n modelini ONNX formatına export eder ve INT8 quantization uygular.
"""

import argparse
import sys
from pathlib import Path

# Add parent to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from tools.shelf.optimize import ModelOptimizer, create_optimizer


def main():
    parser = argparse.ArgumentParser(description="Export YOLOv8n to ONNX and quantize to INT8")
    parser.add_argument("--model", default="yolov8n.pt", help="Input model path (default: yolov8n.pt)")
    parser.add_argument("--onnx", default="yolov8n.onnx", help="Output ONNX path")
    parser.add_argument("--int8", default="yolov8n_int8.onnx", help="Output INT8 ONNX path")
    parser.add_argument("--imgsz", type=int, default=640, help="Input image size")
    parser.add_argument("--half", action="store_true", help="Use FP16 (half precision)")
    parser.add_argument("--device", default="cpu", choices=["cpu", "cuda"], help="Device for export")
    parser.add_argument("--benchmark", action="store_true", help="Run benchmark after export")
    parser.add_argument("--iterations", type=int, default=10, help="Benchmark iterations")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("YOLOv8n ONNX Export & INT8 Quantization")
    print("=" * 60)
    
    # Create optimizer
    print(f"\nLoading model: {args.model}")
    optimizer = create_optimizer(args.model, args.device)
    
    # Export ONNX
    print(f"\nExporting to ONNX: {args.onnx}")
    print(f"  imgsz={args.imgsz}, half={args.half}, device={args.device}")
    onnx_path = optimizer.export_onnx(args.onnx, imgsz=args.imgsz, half=args.half)
    print(f"  ✓ ONNX exported to: {onnx_path}")
    
    # Quantize to INT8
    print(f"\nQuantizing to INT8: {args.int8}")
    int8_path = optimizer.quantize_onnx_int8(onnx_path, args.int8)
    print(f"  ✓ INT8 model saved to: {int8_path}")
    
    # Benchmark
    if args.benchmark:
        print(f"\nRunning benchmark ({args.iterations} iterations)...")
        import cv2
        import numpy as np
        
        # Create test image
        test_img = np.random.randint(0, 255, (args.imgsz, args.imgsz, 3), dtype=np.uint8)
        
        # Benchmark PyTorch
        print("  PyTorch model...")
        pytorch_results = optimizer.benchmark(test_img, iterations=args.iterations)
        print(f"    Mean: {pytorch_results['mean_ms']:.1f}ms, FPS: {pytorch_results['fps']:.1f}")
        
        # Benchmark ONNX
        print("  ONNX model...")
        onnx_results = optimizer.benchmark_onnx(onnx_path, test_img, iterations=args.iterations)
        print(f"    Mean: {onnx_results['mean_ms']:.1f}ms, FPS: {onnx_results['fps']:.1f}")
        
        # Benchmark INT8
        print("  INT8 model...")
        int8_results = optimizer.benchmark_onnx(int8_path, test_img, iterations=args.iterations)
        print(f"    Mean: {int8_results['mean_ms']:.1f}ms, FPS: {int8_results['fps']:.1f}")
        
        # Summary
        speedup = pytorch_results['mean_ms'] / int8_results['mean_ms']
        print(f"\n  📊 Speedup: PyTorch → INT8 = {speedup:.2f}x faster")
    
    print("\n" + "=" * 60)
    print("Export completed successfully!")
    print("=" * 60)
    print(f"Files created:")
    print(f"  - {onnx_path}")
    print(f"  - {int8_path}")
    print(f"\nUsage in scanner:")
    print(f"  scanner = ShelfScanner(use_onnx=True, onnx_path='{int8_path}')")


if __name__ == "__main__":
    main()