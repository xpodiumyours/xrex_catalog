import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/xrex_ocr_line.dart';
import '../models/xrex_ocr_result.dart';

class XRexOcrService {
  const XRexOcrService();

  Future<String> readTextFromImagePath(String imagePath) async {
    final result = await readResultFromImagePath(imagePath);
    return result.rawText;
  }

  Future<XRexOcrResult> readResultFromImagePath(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final lines = <XRexOcrLine>[];

      for (
        var blockIndex = 0;
        blockIndex < recognizedText.blocks.length;
        blockIndex += 1
      ) {
        final block = recognizedText.blocks[blockIndex];
        for (
          var lineIndex = 0;
          lineIndex < block.lines.length;
          lineIndex += 1
        ) {
          final line = block.lines[lineIndex];
          final text = line.text.trim();
          if (text.isEmpty) continue;

          lines.add(
            XRexOcrLine(
              text: text,
              boundingBox: line.boundingBox,
              blockIndex: blockIndex,
              lineIndex: lineIndex,
            ),
          );
        }
      }

      return XRexOcrResult(rawText: recognizedText.text.trim(), lines: lines);
    } finally {
      await textRecognizer.close();
    }
  }
}
