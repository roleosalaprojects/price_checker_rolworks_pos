import 'dart:async';

import 'package:flutter/material.dart';
import 'package:price_checker/components/custom_text.dart';
import 'package:price_checker/components/custom_text_field.dart';
import 'package:price_checker/models/ProductModel.dart';
import 'package:price_checker/services/HTTPService.dart';

class PriceCheckerPage extends StatefulWidget {
  const PriceCheckerPage({super.key});

  @override
  State<PriceCheckerPage> createState() => _PriceCheckerPageState();
}

class _PriceCheckerPageState extends State<PriceCheckerPage> {
  late List<dynamic> products;
  late Timer timer;
  TextEditingController searchController = TextEditingController();
  bool _isEmpty = true;
  //get products
  Future<void> onSubmitted(String value) async {
    if (value.length > 2) {
      var response = await httpGet('/items/search', {'query': value});
      products = response.map((e) => ProductModel.fromJson(e)).toList();
      if (products.length == 0) {
        DialogAlert("No Product Found!");
      }
      setState(() {
        _isEmpty = (products.length > 0) ? false : true;
      });
    } else {
      DialogAlert("Please enter at least 3 or more letters.");
    }
    searchController.clear();
    focusOnSearch();
    if (!timer.isActive) startTimer();
  }

  //showdialog
  void DialogAlert(String msg) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: CustomText(
            content: msg,
            fontSize: 40,
          ),
          actions: [
            ElevatedButton(
              child: const CustomText(content: "Ok", fontSize: 30),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  //focus on search text field
  FocusNode searchFocus = FocusNode();

  //Focus on TextField
  void focusOnSearch() {
    searchFocus.requestFocus();
  }

  //setTimer to revert back to original state
  void startTimer() {
    timer = Timer(const Duration(seconds: 10), () {
      setState(() {
        _isEmpty = true;
      });
    });
  }

  Widget ProductStatusWidget() {
    if (_isEmpty) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Padding(
            padding: EdgeInsets.all(50),
            child: CustomText(
              content: "Put the item in the scanner\nto check the price.",
              fontSize: 60,
            ),
          ),
        ),
      );
    } else {
      if (products.length == 1) {
        return Align(
          alignment: Alignment.center,
          child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(100),
                child: Column(
                  children: [
                    CustomText(content: products[0].name, fontSize: 45),
                    CustomText(
                        content: products[0].price.toStringAsFixed(2),
                        fontSize: 40)
                  ],
                ),
              )),
        );
      } else {
        return Flexible(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: products.length,
              itemBuilder: (context, index) {
                if (products.length == 1) {
                } else if (products.length > 0) {
                  return Padding(
                    padding: EdgeInsets.all(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        title: CustomText(
                          content:
                              "${products[index].name!} - ₱ ${products[index].price!.toStringAsFixed(2)}",
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                  );
                } else {
                  return const CustomText(
                      content: "No Data Available", fontSize: 45);
                }
              },
            ),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    focusOnSearch();
    startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 250,
          ),
          ProductStatusWidget(),
          Container(
            width: 250,
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Tap here, then scan to get Product Details",
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              autofocus: true,
              focusNode: searchFocus,
              controller: searchController,
              textInputAction: TextInputAction.go,
              onSubmitted: onSubmitted,
            ),
          )
        ],
      ),
    );
  }
}
