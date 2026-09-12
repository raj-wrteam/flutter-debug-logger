import 'package:material_ui/material_ui.dart';

class CustomDivider extends StatelessWidget {
  final double height;
  final double indent;
  final double endIndent;
  final Color color;

  const CustomDivider({
    super.key,
    this.height = 1.0,
    this.indent = 0.0,
    this.endIndent = 0.0,
    this.color = Colors.white10,
  });

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      color: color,
      indent: indent,
      endIndent: endIndent,
    );
  }
}
