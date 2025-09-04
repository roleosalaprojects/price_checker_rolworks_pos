//Hive Boxes
import 'package:hive/hive.dart';

import '../services/HTTPService.dart';

String deviceBox = 'price_checker_settings';
dynamic hiveBox;

void initDevice() async {
  hiveBox = await Hive.openBox(deviceBox);
  _initServerIP();
}

// Get Server IP
void _initServerIP() {
  var address = hiveBox.get('server_address');
  if (address == null || address == '') {
    // This is the dev server
    host = 'localhost:8080';
  } else {
    // Set Prod server if IP assignment is different.
    host = address;
  }
}

String getServerIP(){
  var address = hiveBox.get('server_address');
  if (address == null || address == '') {
    // This is the dev server
    host = 'localhost:8080';
  } else {
    // Set Prod server if IP assignment is different.
    host = address;
  }
  print(address);
  return host;
}

void saveServerIP(String hostAddress) {
  host = hostAddress;
  hiveBox.put('server_address', hostAddress);
}
