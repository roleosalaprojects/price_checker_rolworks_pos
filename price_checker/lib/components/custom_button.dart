import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String content;
  final VoidCallback onTap;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? textColor;
  final Color? bgColor;
  final double? height;
  final double? width;
  const CustomButton({
    super.key,
    required this.content,
    required this.onTap,
    this.fontSize,
    this.fontWeight,
    this.bgColor,
    this.height,
    this.width,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          color: bgColor ?? Theme.of(context).colorScheme.primary,
        ),
        child: Center(
          child: Text(
            content,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor ?? Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
        ),
      ),
    );
  }
}
