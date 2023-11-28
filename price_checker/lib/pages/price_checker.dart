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
  TextEditingController searchController = TextEditingController();
  bool _isEmpty = true;
  //get products
  Future<void> onSubmitted(String value) async {
    var response = await httpGet('/items/search', {'query': value});
    print(response.toString());
    products = response.map((e) => ProductModel.fromJson(e)).toList();
    setState(() {
      _isEmpty = (products.length > 0) ? false : true;
    });
  }

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
          _isEmpty
              ? const Center(
                  child: CustomText(
                    content: "Put the item in the scanner\nto check the price.",
                    fontSize: 45,
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      if (products.length == 1) {
                        return Align(
                          alignment: Alignment.bottomLeft,
                          child: Center(
                            child: CustomText(
                              content: products[index].name,
                              fontSize: 30,
                            ),
                          ),
                        );
                      } else if (products.length > 0) {
                        return ListTile(
                          title: CustomText(
                            content:
                                "${products[index].name!} - ${products[index].price!.toStringAsFixed(2)}",
                            fontSize: 16.0,
                          ),
                        );
                      } else {
                        return const CustomText(
                            content: "No Data Available", fontSize: 45);
                      }
                    },
                  ),
                ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "Tap here, then scan to get Product Details",
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: onSubmitted,
            ),
          )
        ],
      ),
    );
  }
}
