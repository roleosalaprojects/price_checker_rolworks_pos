import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'log_service.dart';

String host = "localhost:8080";
const String apiRoute = "/api/desktop";

final http.Client _client = http.Client();

class HttpException implements Exception {
  final String message;
  final int? statusCode;

  HttpException(this.message, {this.statusCode});

  @override
  String toString() =>
      'HttpException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

Future<Map<String, dynamic>> httpGet(
  String route,
  Map<String, dynamic>? queryParameters,
) async {
  final url = Uri.http(host, apiRoute + route, queryParameters);
  logger.d('GET: $url');

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

    logger
        .d('Response [${response.statusCode}]: ${response.body.length} bytes');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      logger.w('HTTP Error [${response.statusCode}]: ${response.body}');
      throw HttpException(
        'Server returned error',
        statusCode: response.statusCode,
      );
    }
  } on SocketException catch (e) {
    logger.e('SocketException on GET $route', error: e);
    throw HttpException('No internet connection or server unreachable');
  } on FormatException catch (e) {
    logger.e('FormatException on GET $route', error: e);
    throw HttpException('Invalid response format from server');
  } catch (e) {
    logger.e('Unexpected error on GET $route', error: e);
    rethrow;
  }
}

Future<Map<String, dynamic>> httpPost(
  String route,
  Map<String, dynamic>? body,
) async {
  final url = Uri.http(host, apiRoute + route);
  logger.d('POST: $url');
  logger.d('Body: $body');

  try {
    final response = await _client
        .post(
          url,
          headers: {
            'Content-type': 'application/json',
            'Accept': 'application/json',
          },
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw HttpException('Request timed out'),
        );

    logger.d('Response [${response.statusCode}]: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      logger.w('HTTP Error [${response.statusCode}]: $errorBody');
      throw HttpException(
        errorBody['message'] ?? 'Server returned error',
        statusCode: response.statusCode,
      );
    }
  } on SocketException catch (e) {
    logger.e('SocketException on POST $route', error: e);
    throw HttpException('No internet connection or server unreachable');
  } on FormatException catch (e) {
    logger.e('FormatException on POST $route', error: e);
    throw HttpException('Invalid response format from server');
  } catch (e) {
    logger.e('Unexpected error on POST $route', error: e);
    rethrow;
  }
}
