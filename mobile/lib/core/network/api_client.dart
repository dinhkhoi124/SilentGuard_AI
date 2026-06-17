import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile/core/config/app_config.dart';

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceFirst(
        RegExp(r'/$'),
        '',
      );

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> getObject(String path) async {
    final response = await _client
        .get(_uri(path), headers: _headers())
        .timeout(AppConfig.networkTimeout);
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException('Phản hồi máy chủ không hợp lệ.');
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await _client
        .get(_uri(path), headers: _headers())
        .timeout(AppConfig.networkTimeout);
    final decoded = _decode(response);
    if (decoded is List<dynamic>) return decoded;
    if (decoded is Map<String, dynamic> && decoded['items'] is List<dynamic>) {
      return decoded['items'] as List<dynamic>;
    }
    throw ApiException('Phản hồi máy chủ không hợp lệ.');
  }

  Future<Map<String, dynamic>> postObject(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(_uri(path), headers: _headers(), body: jsonEncode(body))
        .timeout(AppConfig.networkTimeout);
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw ApiException('Phản hồi máy chủ không hợp lệ.');
  }

  Future<void> delete(String path) async {
    final response = await _client
        .delete(_uri(path), headers: _headers())
        .timeout(AppConfig.networkTimeout);
    _decode(response, allowEmpty: true);
  }

  Uri _uri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$normalizedPath');
  }

  Map<String, String> _headers() {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (AppConfig.backendAuthToken.isNotEmpty)
        'Authorization': 'Bearer ${AppConfig.backendAuthToken}',
    };
  }

  Object? _decode(http.Response response, {bool allowEmpty = false}) {
    final success = response.statusCode >= 200 && response.statusCode < 300;
    if (success && response.body.trim().isEmpty && allowEmpty) return null;

    final body = response.body.trim().isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));

    if (success) return body;
    throw ApiException(_extractError(body, response.statusCode));
  }

  String _extractError(Object? body, int statusCode) {
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail is Map<String, dynamic>) {
        final error = detail['error'];
        if (error is Map<String, dynamic> && error['message'] is String) {
          return error['message'] as String;
        }
        if (detail['message'] is String) return detail['message'] as String;
      }
      if (detail is String) return detail;
      if (body['message'] is String) return body['message'] as String;
    }
    return 'Máy chủ trả về lỗi $statusCode.';
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
