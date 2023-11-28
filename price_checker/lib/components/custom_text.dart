import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  final String content;
  final double fontSize;
  const CustomText({
    super.key,
    required this.content,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      content,
      style: TextStyle(fontSize: fontSize),
    );
  }
}
