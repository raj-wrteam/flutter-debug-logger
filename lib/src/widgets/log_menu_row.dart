import 'package:flutter/material.dart';

class LogMenuRow extends StatelessWidget {
  const LogMenuRow(this.icon, this.label, {super.key, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? Colors.white70, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
