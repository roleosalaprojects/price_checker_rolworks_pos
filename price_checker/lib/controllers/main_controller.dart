import 'package:hive/hive.dart';

import '../services/http_service.dart';
import 'theme_controller.dart';

const String _deviceBoxName = 'price_checker_settings';
const String _serverAddressKey = 'server_address';
const String _storeIdKey = 'store_id';
const String _defaultHost = 'localhost:8080';
const int _defaultStoreId = 1;

Box<dynamic>? _hiveBox;
ThemeController? themeController;
int currentStoreId = _defaultStoreId;

Future<void> initDevice() async {
  _hiveBox = await Hive.openBox(_deviceBoxName);
  _loadServerIP();
  _loadStoreId();
  themeController = ThemeController(_hiveBox);
}

void _loadServerIP() {
  final address = _hiveBox?.get(_serverAddressKey);
  host = (address == null || address.toString().isEmpty) ? _defaultHost : address;
}

void _loadStoreId() {
  final storeId = _hiveBox?.get(_storeIdKey);
  currentStoreId = (storeId == null) ? _defaultStoreId : storeId;
}

String getServerIP() {
  _loadServerIP();
  return host;
}

void saveServerIP(String hostAddress) {
  host = hostAddress;
  _hiveBox?.put(_serverAddressKey, hostAddress);
}

int getStoreId() {
  _loadStoreId();
  return currentStoreId;
}

void saveStoreId(int storeId) {
  currentStoreId = storeId;
  _hiveBox?.put(_storeIdKey, storeId);
}
