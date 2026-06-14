import 'package:flutter/material.dart';

class XRexGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color accentColor;
  final bool strongGlow;

  const XRexGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.accentColor = const Color(0xFF06B6D4),
    this.strongGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xF2111A2D), Color(0xF20A1020)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: strongGlow ? 0.22 : 0.10),
            blurRadius: strongGlow ? 34 : 22,
            offset: const Offset(0, 18),
          ),
          const BoxShadow(
            color: Color(0xAA020617),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class XRexSectionHeader extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String? trailing;

  const XRexSectionHeader({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF062D3B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x6606B6D4)),
          ),
          child: Icon(icon, color: const Color(0xFF22D3EE), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: Color(0xFF67E8F9),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}
