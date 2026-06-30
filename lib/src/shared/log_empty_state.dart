import 'package:flutter/material.dart';
import 'custom_text.dart';

class LogEmptyState extends StatelessWidget {
  const LogEmptyState({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.article_outlined, color: Colors.white12, size: 48),
          const SizedBox(height: 12),
          CustomText(text,
              style: const TextStyle(color: Colors.white30, fontSize: 14)),
        ],
      ),
    );
  }
}
