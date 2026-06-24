import 'xrex_draft_product.dart';

enum XRexMessageType { text, image, productCard, actionResult }

class XRexChatMessage {
  final String text;
  final bool isBot;
  final DateTime timestamp;
  final XRexMessageType type;
  final List<XRexQuickReply> quickReplies;
  final XRexDraftProduct? associatedProduct;
  final String? imagePath;

  XRexChatMessage({
    required this.text,
    this.isBot = true,
    DateTime? timestamp,
    this.type = XRexMessageType.text,
    this.quickReplies = const [],
    this.associatedProduct,
    this.imagePath,
  }) : timestamp = timestamp ?? DateTime.now();
}

class XRexQuickReply {
  final String label;
  final String payload;

  const XRexQuickReply({
    required this.label,
    required this.payload,
  });
}
