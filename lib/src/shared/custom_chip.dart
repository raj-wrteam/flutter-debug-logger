import 'package:flutter/material.dart';
import 'custom_text.dart';

class CustomChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final bool showDot;
  final Color? textColor;

  const CustomChip({
    super.key,
    required this.label,
    required this.color,
    this.selected = true,
    this.onTap,
    this.borderRadius = 4.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    this.fontSize = 11.0,
    this.fontWeight = FontWeight.w600,
    this.letterSpacing = 0.3,
    this.showDot = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? (selected ? color : Colors.white54);

    Widget chip = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: padding,
      decoration: BoxDecoration(
        color: selected ? color.withAlpha(30) : const Color(0xFF202020),
        border: Border.all(
          color: selected ? color.withAlpha(80) : Colors.white10,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: selected ? color : color.withAlpha(102),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          CustomText(
            label,
            style: TextStyle(
              color: effectiveTextColor,
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: letterSpacing,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      chip = GestureDetector(
        onTap: onTap,
        child: chip,
      );
    }

    return chip;
  }
}
