# Changelog - tools.shelf

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-shelf] - 2026-08-24

### Added
- **Core Pipeline**: Complete shelf scanning pipeline (Detection → OCR → Matching → Export)
- **Detector Module** (`detector.py`): YOLOv8n wrapper with ONNX/NCNN/TFLite export support
- **OCR Module** (`ocr.py`): PaddleOCR 3.x integration with Turkish price pattern extraction
- **Matcher Module** (`matcher.py`): Spatial price-product matching with geometric heuristics
- **Parser Module** (`parser.py`): Pipeline orchestration with ScanResult dataclass
- **Exporter Module** (`exporter.py`): Multi-format export (JSON, CSV, COCO, YOLO)
- **Segmenter Module** (`segmenter.py`): MobileSAM integration (optional, lazy-loaded)
- **Optimize Module** (`optimize.py`): Model optimization utilities (ONNX, INT8, NCNN, batch OCR)
- **Logging Utils** (`logging_utils.py`): Structured JSON logging, error hierarchy, retry policies, timeout guard

### Testing
- **12 Unit Tests** (`test_matcher.py`): Matcher heuristics, edge cases, custom weights
- **18 Integration Tests** (`test_pipeline.py`): Full pipeline, exporters, error handling
- **Total**: 30 tests passing

### Configuration
- **Requirements**: `requirements-shelf.txt` with all dependencies
- **Model Downloader**: `download_models.py` for YOLOv8n and MobileSAM weights
- **Retail Classes**: COCO subset filtering (39-79) with `retail_only` flag

### Documentation
- **README.md**: Quick start, API examples, configuration, architecture overview
- **ARCHITECTURE.md**: Data flow, module responsibilities, matching algorithm, error handling
- **TROUBLESHOOTING.md**: Common errors, solutions, fine-tune guide, debug tips

### Technical Decisions (ADR)
- **ADR-EK01**: Local-first, zero-cloud pipeline ($0 cost)
- **ADR-EK02**: Foundation model over custom training (YOLOv8n COCO + fine-tune later)
- **ADR-EK03**: Geometric heuristic matching over ML-based (no labeled data needed)

## [Unreleased]

### Planned
- Fine-tuned model weights (SKU-110K / RPC)
- Grounding DINO zero-shot detector integration
- Real-time video stream support
- Web demo (Streamlit/Gradio)
- Docker image
- CI/CD pipeline with GitHub Actions
- Prometheus metrics endpoint
- OpenTelemetry tracing

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 0.1.0-shelf | 2026-08-24 | Initial release - complete pipeline with tests and docs |

---

## Migration Guide

### From 0.0.x (development) to 0.1.0-shelf

No breaking changes - this is the first stable release.

---

## Contributors

- Kilo AI Assistant (architecture, implementation, tests, documentation)

---

## License

MIT License - see LICENSE file for details.