import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/video_upload/domain/entities/video_upload_result.dart';

abstract interface class VideoUploadRemoteDatasource {
  Future<VideoUploadResult> uploadVideo({
    required String householdId,
    required File videoFile,
  });
}

class VideoUploadRemoteDatasourceImpl implements VideoUploadRemoteDatasource {
  VideoUploadRemoteDatasourceImpl({
    FirebaseAuth? firebaseAuth,
    http.Client? client,
    String? baseUrl,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceFirst(
         RegExp(r'/$'),
         '',
       );

  final FirebaseAuth _firebaseAuth;
  final http.Client _client;
  final String _baseUrl;

  @override
  Future<VideoUploadResult> uploadVideo({
    required String householdId,
    required File videoFile,
  }) async {
    final token = await _firebaseAuth.currentUser?.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        kind: ApiExceptionKind.unauthorized,
      );
    }

    final request =
        http.MultipartRequest('POST', _uri('/api/events/upload-video'))
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['Accept'] = 'application/json'
          ..fields['household_id'] = householdId
          ..files.add(
            await http.MultipartFile.fromPath('file', videoFile.path),
          );

    final streamedResponse = await _client
        .send(request)
        .timeout(AppConfig.networkTimeout);
    final response = await http.Response.fromStream(streamedResponse);
    final decoded = _decode(response);

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        'Phản hồi máy chủ không hợp lệ.',
        kind: ApiExceptionKind.invalidResponse,
      );
    }

    final uploadId = decoded['upload_id'];
    if (uploadId is! String || uploadId.isEmpty) {
      throw const ApiException(
        'Phản hồi máy chủ thiếu upload_id.',
        kind: ApiExceptionKind.invalidResponse,
      );
    }

    return VideoUploadResult(uploadId: uploadId);
  }

  Uri _uri(String path) {
    if (_baseUrl.isEmpty) {
      throw const ApiException(
        'Chưa cấu hình địa chỉ máy chủ.',
        kind: ApiExceptionKind.configuration,
      );
    }

    final baseUri = Uri.tryParse(_baseUrl);
    if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
      throw const ApiException(
        'Địa chỉ máy chủ không hợp lệ.',
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

  Object? _decode(http.Response response) {
    Object? body;
    if (response.body.trim().isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw const ApiException(
            'Phản hồi máy chủ không đúng định dạng JSON.',
            kind: ApiExceptionKind.invalidResponse,
          );
        }
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return body;

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
      final detail = body['detail'];
      if (detail is String) return detail;
      if (body['message'] is String) return body['message'] as String;
      if (body['error'] is String) return body['error'] as String;
    }
    return 'Máy chủ trả về lỗi $statusCode.';
  }
}
