// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:xrex_catalog/models/xrex_ocr_line.dart';
import 'package:xrex_catalog/models/xrex_ocr_result.dart';
import 'package:xrex_catalog/services/interfaces/xrex_ocr_service.dart';
import 'xrex_image_preprocessing_service.dart';

class XRexOcrService implements XRexOcrServiceInterface {
  final XRexImagePreprocessingService preprocessingService;

  const XRexOcrService({
    this.preprocessingService = const XRexImagePreprocessingService(),
  });

  @override
  Future<String> readTextFromImagePath(String imagePath) async {
    final result = await readResultFromImagePath(imagePath);
    return result.rawText;
  }

  @override
  Future<XRexOcrResult> readResultFromImagePath(String imagePath) async {
    final optimizedFile = await preprocessingService.preprocessImageForOcr(File(imagePath));
    final inputImage = InputImage.fromFilePath(optimizedFile.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      final lines = <XRexOcrLine>[];

      for (var blockIndex = 0; blockIndex < recognizedText.blocks.length; blockIndex++) {
        final block = recognizedText.blocks[blockIndex];
        for (var lineIndex = 0; lineIndex < block.lines.length; lineIndex++) {
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

  @override
  Future<XRexOcrResult> readResultFromImageBytes(Uint8List bytes) async {
    return XRexOcrResult.empty;
  }
}