import 'dart:async';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:price_checker/components/custom_icon_button.dart';
import 'package:price_checker/components/custom_text.dart';
import 'package:price_checker/pages/products/product_details_page.dart';
import 'package:price_checker/services/HTTPService.dart';
import 'package:price_checker/services/helpers.dart';

import '../controllers/price_checker_page_controller.dart';
import '../models/product_model.dart';

class PriceCheckerPage extends StatefulWidget {
  const PriceCheckerPage({super.key});

  @override
  State<PriceCheckerPage> createState() => _PriceCheckerPageState();
}

class _PriceCheckerPageState extends State<PriceCheckerPage> {
  late Timer timer;
  TextEditingController searchController = TextEditingController();
  bool _isEmpty = true;
  //get products
  Future<void> onSubmitted(String value) async {
    if (value.length > 2) {
      var response = await httpGet('/items/search', {'term': value});
      response = response['products'];
      products = response.map((e) => ProductModel.fromJson(e)).toList();
      if (products.length == 0) {
        // DialogAlert(context, "No Product Found!");
        showSnack(
          customSnack(
              'Product not found.',
              "We can't seem to find the product you are looking for. Please ask cashiers for more info.",
              ContentType.failure),
          context,
        );
      }
      setState(() {
        _isEmpty = (products.length > 0) ? false : true;
      });
    } else {
      // DialogAlert(context, "Please enter at least 3 or more letters.");
      showSnack(
        customSnack(
          'Not enough keywords!',
          "Please enter at least 3 or more letters.",
          ContentType.warning,
        ),
        context,
      );
    }
    searchController.clear();
    focusOnSearch();
    if (!timer.isActive) startTimer();
  }

  //focus on search text field
  FocusNode searchFocus = FocusNode();

  //Focus on TextField
  void focusOnSearch() {
    searchFocus.requestFocus();
  }

  //setTimer to revert back to original state
  void startTimer() {
    timer = Timer(const Duration(seconds: 6), () {
      setState(() {
        _isEmpty = true;
      });
    });
  }

  Widget ProductStatusWidget() {
    if (_isEmpty) {
      return const Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: double.maxFinite,
          child: Padding(
            padding: EdgeInsets.all(25),
            child: CustomText(
              content: "Scan here\nto check prices.",
              fontSize: 60,
              fontWeight: FontWeight.w600,
              overFlow: TextOverflow.visible,
            ),
          ),
        ),
      );
    } else {
      if (products.length == 1) {
        return ProductDetailsPage(product: products[0]);
      } else {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (context, index) {
              if(products.isNotEmpty){
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
                        "${products[index].name!} - ₱ ${numberFormatter.format(getProductPrice(products[index]))}",
                        fontSize: 16.0,
                      ),
                    ),
                  ),
                );
              }else{
                return const CustomText(
                  content: "No Data Available",
                  fontSize: 45,
                );
              }
            },
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), (){focusOnSearch();});
    startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Container(
        decoration: BoxDecoration(color: appColor),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CustomIconButton(
                onTap: () => promptHostDialog(context),
                backgroundColor: appColor,
                iconColor: Colors.white70,
                icon: Icons.settings,
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0, right: 10.0),
                      child: ClipRRect(
                        clipBehavior: Clip.hardEdge,
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.asset(
                          'assets/transparent_store.png',
                          width: 200.0,
                          height: 200.0,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ProductStatusWidget(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(25.0),
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
      ),
    );
  }
}
