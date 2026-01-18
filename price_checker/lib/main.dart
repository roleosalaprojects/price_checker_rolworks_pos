import 'package:flutter/material.dart';
import 'package:price_checker/pages/price_checker_page.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'controllers/main_controller.dart';
import 'controllers/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initDevice();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController!,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeController!.themeMode,
          home: const PriceCheckerPage(),
        );
      },
    );
  }
}
