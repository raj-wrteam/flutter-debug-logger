import 'package:flutter/material.dart';
import 'custom_text.dart';

class CustomTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color textColor;
  final double fontSize;

  const CustomTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.textColor,
    this.fontSize = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: CustomText(
        label,
        style: TextStyle(color: textColor, fontSize: fontSize),
      ),
    );
  }
}
