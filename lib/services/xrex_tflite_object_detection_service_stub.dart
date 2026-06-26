import 'dart:typed_data';

import '../models/xrex_detected_region.dart';

class XRexTfliteObjectDetectionService {
  const XRexTfliteObjectDetectionService();

  Future<List<XRexDetectedRegion>> detectObjectsFromImageBytes(
    Uint8List imageBytes,
  ) async {
    return const [];
  }
}
