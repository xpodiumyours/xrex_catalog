import 'dart:ui';

class XRexOcrLine {
  final String text;
  final Rect boundingBox;
  final int blockIndex;
  final int lineIndex;

  const XRexOcrLine({
    required this.text,
    required this.boundingBox,
    required this.blockIndex,
    required this.lineIndex,
  });

  double get centerX => boundingBox.left + (boundingBox.width / 2);

  double get centerY => boundingBox.top + (boundingBox.height / 2);

  factory XRexOcrLine.fromJson(Map<String, dynamic> json) {
    final box = json['boundingBox'] as Map<String, dynamic>;
    return XRexOcrLine(
      text: json['text'] as String,
      blockIndex: json['blockIndex'] as int,
      lineIndex: json['lineIndex'] as int,
      boundingBox: Rect.fromLTRB(
        (box['left'] as num).toDouble(),
        (box['top'] as num).toDouble(),
        (box['right'] as num).toDouble(),
        (box['bottom'] as num).toDouble(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'blockIndex': blockIndex,
      'lineIndex': lineIndex,
      'boundingBox': {
        'left': boundingBox.left,
        'top': boundingBox.top,
        'right': boundingBox.right,
        'bottom': boundingBox.bottom,
        'width': boundingBox.width,
        'height': boundingBox.height,
      },
    };
  }
}
