import 'package:flutter/material.dart';
import 'custom_text.dart';

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isElevated;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderSide? side;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isElevated = false,
    this.backgroundColor,
    this.foregroundColor,
    this.side,
    this.padding,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );

    if (isElevated) {
      if (icon != null) {
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: CustomText(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            padding: padding,
            elevation: 0,
            shape: shape,
          ),
        );
      }
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: padding,
          elevation: 0,
          shape: shape,
        ),
        child: CustomText(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      );
    } else {
      if (icon != null) {
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: CustomText(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor,
            side: side,
            padding: padding,
            shape: shape,
          ),
        );
      }
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: side,
          padding: padding,
          shape: shape,
        ),
        child: CustomText(label),
      );
    }
  }
}
