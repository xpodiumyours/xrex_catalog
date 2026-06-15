import 'xrex_ocr_line.dart';

class XRexOcrResult {
  final String rawText;
  final List<XRexOcrLine> lines;

  const XRexOcrResult({required this.rawText, required this.lines});

  static const empty = XRexOcrResult(rawText: '', lines: []);
}
