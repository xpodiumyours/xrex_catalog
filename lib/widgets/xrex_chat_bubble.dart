import 'package:flutter/material.dart';
import '../models/xrex_chat_message.dart';
import '../models/xrex_draft_product.dart';

class XRexChatBubble extends StatelessWidget {
  final XRexChatMessage message;

  const XRexChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isBot = message.isBot;
    final isProduct = message.associatedProduct != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment:
                isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isBot) _buildAvatar(),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isProduct ? 12 : 16,
                    vertical: isProduct ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isBot
                            ? const Color(0xF20B1220)
                            : const Color(0xFF06B6D4),
                    borderRadius: _getBorderRadius(isBot),
                    border:
                        isBot
                            ? Border.all(
                              color: const Color(0x3322D3EE),
                              width: 1,
                            )
                            : null,
                    boxShadow: [
                      BoxShadow(
                        color: (isBot
                                ? const Color(0xFF020617)
                                : const Color(0xFF06B6D4))
                            .withValues(alpha: isBot ? 0.28 : 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child:
                      isProduct
                          ? _buildProductPreview(message.associatedProduct!)
                          : Text(
                            message.text,
                            style: TextStyle(
                              color:
                                  isBot
                                      ? const Color(0xFFE5E7EB)
                                      : Colors.black,
                              fontSize: 14,
                              height: 1.5,
                              fontWeight:
                                  isBot ? FontWeight.w400 : FontWeight.w700,
                            ),
                          ),
                ),
              ),
              const SizedBox(width: 6),
              if (!isBot) _buildUserAvatar(),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isBot ? 52 : 0,
              right: isBot ? 0 : 48,
            ),
            child: Text(
              _formatTime(message.timestamp),
              style: const TextStyle(
                color: Colors.white10,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductPreview(XRexDraftProduct product) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getCategoryIcon(product.category),
                  size: 12,
                  color: const Color(0xFF06B6D4),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                product.price.isNotEmpty ? "${product.price} TL" : "Fiyat Yok",
                style: const TextStyle(
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 26),
              Text(
                product.category,
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Text(
                "Düzenle",
                style: TextStyle(
                  color: Color(0xFF06B6D4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Gözlük':
        return Icons.remove_red_eye_rounded;
      case 'Giyim':
        return Icons.checkroom_rounded;
      case 'Aktar ürünleri':
        return Icons.eco_rounded;
      case 'Hırdavat':
        return Icons.build_rounded;
      case 'Kozmetik':
        return Icons.face_rounded;
      case 'Kırtasiye':
        return Icons.edit_note_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF062D3B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x6606B6D4)),
      ),
      child: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF06B6D4)),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x3322D3EE)),
      ),
      child: const Icon(Icons.person_rounded, size: 14, color: Colors.white24),
    );
  }

  BorderRadius _getBorderRadius(bool isBot) {
    return BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isBot ? 2 : 14),
      bottomRight: Radius.circular(isBot ? 14 : 2),
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
