// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:typed_data';
import 'dart:ui';

import '../models/xrex_ocr_line.dart';
import '../models/xrex_ocr_result.dart';
import 'interfaces/xrex_ocr_service.dart';

class XRexOcrService implements XRexOcrServiceInterface {
  const XRexOcrService();

  @override
  Future<String> readTextFromImagePath(String imagePath) async {
    return '';
  }

  @override
  Future<XRexOcrResult> readResultFromImagePath(String imagePath) async {
    return XRexOcrResult.empty;
  }

  @override
  Future<XRexOcrResult> readResultFromImageBytes(Uint8List bytes) async {
    final base64Str = base64Encode(bytes);
    final dataUrl = 'data:image/jpeg;base64,$base64Str';
    try {
      final completer = Completer<String>();
      js.context['__onOcrComplete'] = (String result) {
        completer.complete(result);
      };

      js.context.callMethod('runOcr', [dataUrl]);

      final jsonResult = await completer.future;
      js.context['__onOcrComplete'] = null;

      final parsed = jsonDecode(jsonResult);
      final rawText = parsed['text'] as String? ?? '';
      final linesData = parsed['lines'] as List<dynamic>? ?? [];

      final lines = <XRexOcrLine>[];
      for (var i = 0; i < linesData.length; i++) {
        final lineData = linesData[i];
        final text = lineData['text'] as String? ?? '';
        final x0 = (lineData['x0'] as num).toDouble();
        final y0 = (lineData['y0'] as num).toDouble();
        final x1 = (lineData['x1'] as num).toDouble();
        final y1 = (lineData['y1'] as num).toDouble();

        lines.add(
          XRexOcrLine(
            text: text,
            boundingBox: Rect.fromLTRB(x0, y0, x1, y1),
            blockIndex: 0,
            lineIndex: i,
          ),
        );
      }

      return XRexOcrResult(rawText: rawText, lines: lines);
    } catch (e) {
      return XRexOcrResult.empty;
    }
  }
}