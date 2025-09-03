import 'package:flutter/material.dart';

class CustomIconButton extends StatelessWidget {
  final Function() onTap;
  final Color backgroundColor;
  final Color iconColor;
  final IconData icon;
  const CustomIconButton({
    super.key,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(17.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Icon(
          icon,
          color: iconColor,
        ),
      ),
    );
  }
}
