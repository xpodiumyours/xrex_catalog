import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class XRexOcrService {
  const XRexOcrService();

  Future<String> readTextFromImagePath(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } finally {
      await textRecognizer.close();
    }
  }
}
