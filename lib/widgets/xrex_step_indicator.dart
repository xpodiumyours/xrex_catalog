import 'package:flutter/material.dart';

class XRexStepIndicator extends StatelessWidget {
  final int activeStep;

  const XRexStepIndicator({super.key, required this.activeStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1728),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2A3D)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStep(
            stepNumber: 1,
            label: 'Fotoğraf',
            context: context,
          ),
          _buildDivider(),
          _buildStep(
            stepNumber: 2,
            label: 'Ürünler',
            context: context,
          ),
          _buildDivider(),
          _buildStep(
            stepNumber: 3,
            label: 'Son Kontrol',
            context: context,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required int stepNumber,
    required String label,
    required BuildContext context,
  }) {
    final isCompleted = stepNumber < activeStep;
    final isActive = stepNumber == activeStep;

    Color color;
    IconData? icon;

    if (isCompleted) {
      color = const Color(0xFF22C55E); // Green
      icon = Icons.check_circle_rounded;
    } else if (isActive) {
      color = const Color(0xFF06B6D4); // Cyan
    } else {
      color = const Color(0xFF475569); // Slate Grey
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, color: color, size: 18)
        else
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.transparent,
              border: Border.all(color: color, width: 2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$stepNumber',
              style: TextStyle(
                color: isActive ? const Color(0xFF090D18) : color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive || isCompleted ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: const Color(0xFF1F2A3D),
      ),
    );
  }
}
