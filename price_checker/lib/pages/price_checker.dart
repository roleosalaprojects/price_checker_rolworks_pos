import 'package:flutter/material.dart';
import 'package:price_checker/components/custom_text.dart';
import 'package:price_checker/components/custom_text_field.dart';

class PriceCheckerPage extends StatefulWidget {
  const PriceCheckerPage({super.key});

  @override
  State<PriceCheckerPage> createState() => _PriceCheckerPageState();
}

class _PriceCheckerPageState extends State<PriceCheckerPage> {
  TextEditingController searchController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const CustomText(
          content: "Price Checker App",
          fontSize: 22.0,
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Center(
            child: CustomText(
              content: "Put the item in the scanner\nto check the price.",
              fontSize: 45,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: CustomTextField(
              controller: searchController,
              hintText: "Tap here, then scan.",
            ),
          )
        ],
      ),
    );
  }
}
