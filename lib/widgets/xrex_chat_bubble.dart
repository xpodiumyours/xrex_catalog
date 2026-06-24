import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/xrex_chat_message.dart';
import '../models/xrex_draft_product.dart';

class XRexChatBubble extends StatelessWidget {
  final XRexChatMessage message;

  const XRexChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isBot = message.isBot;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isBot) _buildAvatar(),
              const SizedBox(width: 8),
              Flexible(
                child: ClipRRect(
                  borderRadius: _getBorderRadius(isBot),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isBot
                            ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                            : const Color(0xFF06B6D4).withValues(alpha: 0.9),
                        borderRadius: _getBorderRadius(isBot),
                        border: Border.all(
                          color: isBot
                              ? const Color(0xFF334155)
                              : Colors.white12,
                          width: 0.5,
                        ),
                      ),
                      child: message.type == XRexMessageType.productCard && message.associatedProduct != null
                          ? _buildProductPreview(message.associatedProduct!)
                          : Text(
                              message.text,
                              style: TextStyle(
                                color: isBot ? Colors.white : Colors.black,
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: isBot ? FontWeight.w400 : FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isBot) _buildUserAvatar(),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isBot ? 48 : 0,
              right: isBot ? 0 : 48
            ),
            child: Text(
              _formatTime(message.timestamp),
              style: const TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductPreview(XRexDraftProduct product) {
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_getCategoryIcon(product.category), size: 14, color: const Color(0xFF06B6D4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${product.category} • ${product.quantity} Adet",
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Text(
                product.price.isNotEmpty ? "${product.price} TL" : "Fiyat Yok",
                style: const TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Gözlük': return Icons.remove_red_eye_outlined;
      case 'Giyim': return Icons.checkroom_outlined;
      case 'Aktar ürünleri': return Icons.eco_outlined;
      case 'Hırdavat': return Icons.build_outlined;
      case 'Kozmetik': return Icons.face_outlined;
      case 'Kırtasiye': return Icons.edit_note_outlined;
      default: return Icons.inventory_2_outlined;
    }
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF04111D)),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2A3D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: const Icon(Icons.person_outline, size: 18, color: Colors.white70),
    );
  }

  BorderRadius _getBorderRadius(bool isBot) {
    return BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isBot ? 4 : 18),
      bottomRight: Radius.circular(isBot ? 18 : 4),
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
