import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  final String content;
  final double fontSize;
  final double? letterSpacing;
  final FontWeight? fontWeight;
  final Color? textColor;
  final TextAlign? textAlign;
  final TextOverflow? overFlow;
  const CustomText({
    super.key,
    required this.content,
    required this.fontSize,
    this.fontWeight,
    this.letterSpacing,
    this.textColor,
    this.textAlign,
    this.overFlow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      content,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: textColor ?? Colors.black,
        letterSpacing: letterSpacing,
        overflow: overFlow ?? TextOverflow.ellipsis,
      ),
    );
  }
}
