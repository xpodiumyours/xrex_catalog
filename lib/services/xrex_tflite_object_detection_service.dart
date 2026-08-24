/// TFLite Object Detection - Platform Interface & Default Export
///
/// This file exports the platform interface and provides a default stub implementation.
/// Platform-specific implementations are conditionally exported via:
/// - `xrex_tflite_object_detection_service_io.dart` for dart.library.io (Android, iOS, Desktop)
/// - `xrex_tflite_object_detection_service_web.dart` for dart.library.html (Web)
export 'xrex_tflite_object_detection_service_platform.dart';
export 'xrex_tflite_object_detection_service_stub.dart'
    if (dart.library.io) 'xrex_tflite_object_detection_service_io.dart'
    if (dart.library.html) 'xrex_tflite_object_detection_service_web.dart';