import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputAction? textInputAction;
  final VoidCallback onSubmitted;
  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.textInputAction,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
      textInputAction: textInputAction,
    );
  }
}
