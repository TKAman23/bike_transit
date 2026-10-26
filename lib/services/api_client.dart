import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.isConfiguration = false});

  final String message;
  final int? statusCode;

  /// The failure is caused by missing/invalid keys or disabled APIs.
  final bool isConfiguration;

  @override
  String toString() => message;
}

/// Thin JSON-over-HTTP helper shared by the API services.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 20);

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final res = await _client.get(uri, headers: headers).timeout(_timeout);
    return _decode(res, uri.host);
  }

  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json', ...?headers},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decode(res, uri.host);
  }

  Map<String, dynamic> _decode(http.Response res, String host) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected response from $host (${res.statusCode}).',
          statusCode: res.statusCode);
    }
    if (res.statusCode >= 400) {
      final error = json['error'];
      final message = error is Map ? error['message'] : null;
      throw ApiException(
        message is String ? message : 'Request to $host failed (${res.statusCode}).',
        statusCode: res.statusCode,
        isConfiguration: res.statusCode == 401 || res.statusCode == 403,
      );
    }
    return json;
  }
}
