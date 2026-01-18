import 'package:hive/hive.dart';

import '../services/http_service.dart';
import 'theme_controller.dart';

const String _deviceBoxName = 'price_checker_settings';
const String _serverAddressKey = 'server_address';
const String _defaultHost = 'localhost:8080';

Box<dynamic>? _hiveBox;
ThemeController? themeController;

Future<void> initDevice() async {
  _hiveBox = await Hive.openBox(_deviceBoxName);
  _loadServerIP();
  themeController = ThemeController(_hiveBox);
}

void _loadServerIP() {
  final address = _hiveBox?.get(_serverAddressKey);
  host = (address == null || address.toString().isEmpty) ? _defaultHost : address;
}

String getServerIP() {
  _loadServerIP();
  return host;
}

void saveServerIP(String hostAddress) {
  host = hostAddress;
  _hiveBox?.put(_serverAddressKey, hostAddress);
}
