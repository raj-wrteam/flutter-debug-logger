import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  final String? text;
  final InlineSpan? textSpan;
  final bool isRich;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;
  final TextScaler? textScaler;

  const CustomText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.textScaler,
  })  : textSpan = null,
        isRich = false;

  const CustomText.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.maxLines,
    this.textScaler,
  })  : text = null,
        isRich = true;

  @override
  Widget build(BuildContext context) {
    if (isRich && textSpan != null) {
      return Text.rich(
        textSpan!,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        textScaler: textScaler,
      );
    }
    return Text(
      text ?? '',
      style: style,
      textAlign: textAlign,
      textDirection: textDirection,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      textScaler: textScaler,
    );
  }
}
