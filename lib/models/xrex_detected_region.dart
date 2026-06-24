import 'dart:ui';

class XRexDetectedRegion {
  final String id;
  final Rect boundingBox;
  final String? label;
  final double? confidence;

  const XRexDetectedRegion({
    required this.id,
    required this.boundingBox,
    this.label,
    this.confidence,
  });

  double get centerX => boundingBox.left + (boundingBox.width / 2);
  double get centerY => boundingBox.top + (boundingBox.height / 2);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'confidence': confidence,
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
