import 'package:flutter/material.dart';
import 'package:price_checker/services/helpers.dart';

import '../../components/custom_text.dart';
import '../../models/product_model.dart';
import '../../services/HTTPService.dart';

class ProductDetailsPage extends StatelessWidget {
  final ProductModel product;
  const ProductDetailsPage({super.key, required this.product});

  List<Widget> displayItemUnits(ProductModel product) {
    List<Widget> widgets = product.itemUnits!.map((e) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CustomText(
            content: e.unit!.name!,
            fontSize: 20.0,
            textColor: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
          CustomText(
            content:
                '₱ ${numberFormatter.format(getProductUnitPrice(product, e))}',
            fontSize: 20.0,
            textColor: Colors.black54,
            fontWeight: FontWeight.w700,
          )
        ],
      );
    }).toList();
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: ClipRRect(
                clipBehavior: Clip.hardEdge,
                borderRadius: BorderRadius.circular(8.0),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.2,
                  width: 300,
                  child: product.image != null
                      ? Image.network(
                          'http://$host/${product.image}',
                          fit: BoxFit.fitWidth,
                          height: 200,
                          width: double.maxFinite,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            color: Colors.grey,
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CustomText(
                                  content: '?',
                                  fontSize: 40,
                                ),
                                CustomText(
                                  content: 'No image found.',
                                  fontSize: 12,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(
              height: 25.0,
            ),
            CustomText(
              content: product.name!,
              fontSize: 25,
            ),
            CustomText(
              content: '₱ ${numberFormatter.format(getProductPrice(product))}',
              fontSize: 40,
              textColor: Colors.black54,
            ),
            const SizedBox(
              height: 25.0,
            ),
            Column(
              children: displayItemUnits(product),
            )
          ],
        ),
      ),
    );
  }
}
