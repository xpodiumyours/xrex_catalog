import 'dart:typed_data';

import '../../models/xrex_ocr_line.dart';
import '../../models/xrex_ocr_result.dart';

abstract class XRexOcrServiceInterface {
  const XRexOcrServiceInterface();

  Future<String> readTextFromImagePath(String imagePath);

  Future<XRexOcrResult> readResultFromImagePath(String imagePath);

  Future<XRexOcrResult> readResultFromImageBytes(Uint8List bytes);
}