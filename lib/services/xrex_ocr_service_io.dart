// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/xrex_ocr_line.dart';
import '../models/xrex_ocr_result.dart';
import 'xrex_image_preprocessing_service.dart';

class XRexOcrService {
  final XRexImagePreprocessingService preprocessingService;

  const XRexOcrService({
    this.preprocessingService = const XRexImagePreprocessingService(),
  });

  Future<String> readTextFromImagePath(String imagePath) async {
    final result = await readResultFromImagePath(imagePath);
    return result.rawText;
  }

  Future<XRexOcrResult> readResultFromImagePath(String imagePath) async {
    // 1. Optimize image for OCR
    final optimizedFile = await preprocessingService.preprocessImageForOcr(File(imagePath));
    
    // 2. Read with ML Kit
    final inputImage = InputImage.fromFilePath(optimizedFile.path);
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

      // Cleanup optimized file after use
      if (optimizedFile.path != imagePath && await optimizedFile.exists()) {
        try {
          await optimizedFile.delete();
        } catch (_) {}
      }

      return XRexOcrResult(rawText: recognizedText.text.trim(), lines: lines);
    } finally {
      await textRecognizer.close();
    }
  }

  Future<XRexOcrResult> readResultFromImageBytes(Uint8List bytes) async {
    return XRexOcrResult.empty;
  }
}
