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

  static const _missingBaseUrlMessage =
      'Chưa cấu hình địa chỉ máy chủ. Hãy chạy app với '
      '--dart-define=API_BASE_URL=https://<backend-domain> '
      'hoặc dùng URL backend đã triển khai.';

  /// Fetches a JSON object at [path] with the given [queryParameters].
  /// Values are URL-encoded automatically via [Uri.replace].
  Future<Map<String, dynamic>> getObjectWithQuery(
    String path,
    Map<String, String> queryParameters,
  ) async {
    final uri = _uri(path).replace(queryParameters: queryParameters);
    final response = await _client
        .get(uri, headers: _headers())
        .timeout(AppConfig.networkTimeout);
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const ApiException(
      'Phản hồi máy chủ không hợp lệ.',
      kind: ApiExceptionKind.invalidResponse,
    );
  }

  Future<Map<String, dynamic>> getObject(String path) async {
    final response = await _client
        .get(_uri(path), headers: _headers())
        .timeout(AppConfig.networkTimeout);
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const ApiException(
      'Phản hồi máy chủ không hợp lệ.',
      kind: ApiExceptionKind.invalidResponse,
    );
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
    throw const ApiException(
      'Phản hồi máy chủ không hợp lệ.',
      kind: ApiExceptionKind.invalidResponse,
    );
  }

  Future<Map<String, dynamic>> postObject(
    String path, [
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
    Duration?
    timeout, // FIX: allow provisionSession login to outlast Render cold starts without changing every API call.
  ]) async {
    final response = await _client
        .post(
          _uri(path),
          headers: _headers(extraHeaders),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(
          timeout ?? AppConfig.networkTimeout,
        ); // FIX: keep existing timeout unless a caller explicitly opts in.
    final decoded = _decode(response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const ApiException(
      'Phản hồi máy chủ không hợp lệ.',
      kind: ApiExceptionKind.invalidResponse,
    );
  }

  Future<int> patch(
    String path, [
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  ]) async {
    final response = await _client
        .patch(
          _uri(path),
          headers: _headers(extraHeaders),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(AppConfig.networkTimeout);
    _decode(response, allowEmpty: true);
    return response.statusCode;
  }

  Future<int> delete(String path) async {
    final response = await _client
        .delete(_uri(path), headers: _headers())
        .timeout(AppConfig.networkTimeout);
    _decode(response, allowEmpty: true);
    return response.statusCode;
  }

  Uri _uri(String path) {
    if (_baseUrl.isEmpty) {
      throw const ApiException(
        _missingBaseUrlMessage,
        kind: ApiExceptionKind.configuration,
      );
    }

    final baseUri = Uri.tryParse(_baseUrl);
    if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
      throw const ApiException(
        'Địa chỉ máy chủ không hợp lệ. Vui lòng kiểm tra API_BASE_URL.',
        kind: ApiExceptionKind.configuration,
      );
    }

    var normalizedPath = path.startsWith('/') ? path : '/$path';
    if (baseUri.path.replaceAll(RegExp(r'/+$'), '').endsWith('/api') &&
        normalizedPath.startsWith('/api/')) {
      normalizedPath = normalizedPath.substring('/api'.length);
    }
    return Uri.parse('$_baseUrl$normalizedPath');
  }

  Map<String, String> _headers([Map<String, String>? extraHeaders]) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?extraHeaders,
    };
  }

  Object? _decode(http.Response response, {bool allowEmpty = false}) {
    final success = response.statusCode >= 200 && response.statusCode < 300;
    if (success && response.body.trim().isEmpty && allowEmpty) return null;

    Object? body;
    if (response.body.trim().isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        if (success) {
          throw const ApiException(
            'Phản hồi máy chủ không đúng định dạng JSON.',
            kind: ApiExceptionKind.invalidResponse,
          );
        }
      }
    }

    if (success) return body;
    throw ApiException(
      _extractError(body, response.statusCode),
      kind: _kindForStatusCode(response.statusCode),
      statusCode: response.statusCode,
    );
  }

  ApiExceptionKind _kindForStatusCode(int statusCode) {
    return switch (statusCode) {
      401 => ApiExceptionKind.unauthorized,
      403 => ApiExceptionKind.forbidden,
      404 => ApiExceptionKind.notFound,
      >= 400 && < 500 => ApiExceptionKind.badRequest,
      >= 500 => ApiExceptionKind.server,
      _ => ApiExceptionKind.unknown,
    };
  }

  String _extractError(Object? body, int statusCode) {
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        return error['message'] as String;
      }
      final detail = body['detail'];
      if (detail is Map<String, dynamic>) {
        final detailError = detail['error'];
        if (detailError is Map<String, dynamic> &&
            detailError['message'] is String) {
          return detailError['message'] as String;
        }
        if (detail['message'] is String) return detail['message'] as String;
      }
      if (detail is String) return detail;
      if (body['message'] is String) return body['message'] as String;
    }
    return 'Máy chủ trả về lỗi $statusCode.';
  }
}

enum ApiExceptionKind {
  configuration,
  invalidResponse,
  unauthorized,
  forbidden,
  notFound,
  badRequest,
  server,
  unknown,
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.kind = ApiExceptionKind.unknown,
    this.statusCode,
  });

  final String message;
  final ApiExceptionKind kind;
  final int? statusCode;

  @override
  String toString() {
    final code = statusCode;
    if (code == null) return message;
    return '$message ($code)';
  }
}
