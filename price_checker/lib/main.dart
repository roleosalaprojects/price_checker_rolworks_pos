import 'package:flutter/material.dart';
import 'package:price_checker/pages/price_checker_page.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'controllers/main_controller.dart';

void main() async {
  await Hive.initFlutter();
  initDevice();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PriceCheckerPage(),
    );
  }
}
