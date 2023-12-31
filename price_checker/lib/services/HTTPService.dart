import 'dart:convert';

import 'package:http/http.dart' as http;

const String host = "192.168.1.201";
const String apiRoute = "/api/desktop";
var client = http.Client();

Future<dynamic> httpGet(
  String route,
  Map<String, dynamic>? queryParameters,
) async {
  var url = Uri.http(host, apiRoute + route, queryParameters);
  var response = await client.get(url, headers: {
    'Content-type': 'application/json',
    'Accept': 'application/json',
  });
  var decodedResponse = jsonDecode(response.body);
  return decodedResponse;
}
