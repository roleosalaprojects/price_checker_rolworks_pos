import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/product_model.dart';

var numberFormatter =
    NumberFormat.decimalPatternDigits(locale: 'en_ph', decimalDigits: 2);

num getProductPrice(ProductModel product) {
  num price = product.price!;
  if (product.price == 0) {
    price = product.cost! + ((product.markup! / 100) * product.cost!);
  }
  return price;
}

num getProductUnitPrice(ProductModel product, ItemUnits itemUnit) {
  num price = itemUnit.price!;
  if (price == 0) {
    num productCost = product.cost!;
    num productMarkUp = product.markup! / 100;
    num unitQty = itemUnit.qty!;
    price = unitQty * (productCost + (productCost * productMarkUp));
  }
  return price;
}

void showSnack(SnackBar banner, BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(banner);
}

SnackBar customSnack(String title, String message, ContentType contentType) {
  return SnackBar(
    /// need to set following properties for best effect of awesome_snackbar_content
    elevation: 0,

    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,

      /// change contentType to ContentType.success, ContentType.warning or ContentType.help for variants
      contentType: contentType,
      // to configure for material banner
      inMaterialBanner: true,
    ),
  );
}
