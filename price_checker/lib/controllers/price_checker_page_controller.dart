//showdialog
import 'package:flutter/material.dart';
import 'package:price_checker/components/custom_text_field.dart';
import 'package:price_checker/controllers/main_controller.dart';

import '../components/custom_button.dart';
import '../components/custom_text.dart';
import '../services/HTTPService.dart';

Color appColor = const Color(0xFFf48d92);

late List<dynamic> products;

void DialogAlert(BuildContext context, String msg) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Padding(
          padding: const EdgeInsets.all(25.0),
          child: CustomText(
            content: msg,
            fontSize: 40,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all<Color>(appColor),
              textStyle: WidgetStateProperty.all<TextStyle>(
                const TextStyle(color: Colors.white70),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: CustomText(content: "Search Again", fontSize: 30),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> promptHostDialog(BuildContext context) {
  TextEditingController controller = TextEditingController(text: host);
  return showDialog(
    context: context,
    builder: (BuildContext subContext) {
      return AlertDialog(
        title: const CustomText(content: 'Server Host', fontSize: 16.0),
        content: CustomTextField(
          controller: controller,
          hintText: 'Server',
          onSubmitted: () {},
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 80.0,
                  child: CustomButton(
                    content: "Save",
                    bgColor: appColor,
                    textColor: Colors.white,
                    onTap: () {
                      host = controller.text;
                      saveServerIP(controller.text);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CustomButton(
                  content: "Cancel",
                  bgColor: Colors.grey,
                  textColor: Colors.white,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
