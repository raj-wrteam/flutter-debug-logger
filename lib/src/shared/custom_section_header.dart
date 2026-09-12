import 'package:material_ui/material_ui.dart';
import 'custom_text.dart';

class CustomSectionHeader extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const CustomSectionHeader(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: CustomText(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
