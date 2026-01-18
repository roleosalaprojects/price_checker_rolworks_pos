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
