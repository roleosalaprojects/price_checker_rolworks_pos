import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

String host = "localhost:8080";
const String apiRoute = "/api/desktop";

final http.Client _client = http.Client();

class HttpException implements Exception {
  final String message;
  final int? statusCode;

  HttpException(this.message, {this.statusCode});

  @override
  String toString() => 'HttpException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

Future<Map<String, dynamic>> httpGet(
  String route,
  Map<String, dynamic>? queryParameters,
) async {
  final url = Uri.http(host, apiRoute + route, queryParameters);

  try {
    final response = await _client.get(
      url,
      headers: {
        'Content-type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw HttpException('Request timed out'),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw HttpException(
        'Server returned error',
        statusCode: response.statusCode,
      );
    }
  } on SocketException {
    throw HttpException('No internet connection or server unreachable');
  } on FormatException {
    throw HttpException('Invalid response format from server');
  }
}
