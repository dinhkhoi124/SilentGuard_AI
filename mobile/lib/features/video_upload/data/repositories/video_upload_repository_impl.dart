import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/video_upload/data/datasources/video_upload_remote_datasource.dart';
import 'package:mobile/features/video_upload/domain/entities/video_upload_result.dart';
import 'package:mobile/features/video_upload/domain/repositories/video_upload_repository.dart';

class VideoUploadRepositoryImpl implements VideoUploadRepository {
  const VideoUploadRepositoryImpl(this._remoteDatasource);

  final VideoUploadRemoteDatasource _remoteDatasource;

  @override
  Future<VideoUploadResult> uploadVideo({
    required String householdId,
    required File videoFile,
  }) async {
    try {
      return await _remoteDatasource.uploadVideo(
        householdId: householdId,
        videoFile: videoFile,
      );
    } on ApiException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      rethrow;
    } on TimeoutException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      throw const VideoUploadException('Upload request timed out.');
    } on SocketException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      throw const VideoUploadException('Upload request failed due to network.');
    } on http.ClientException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      throw const VideoUploadException('Upload HTTP client request failed.');
    } catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      throw const VideoUploadException('Upload request failed.');
    }
  }

  void _logFailure(Object error, StackTrace stackTrace) {
    developer.log(
      'Video upload request failed.',
      name: 'VideoUploadRepository',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class VideoUploadException implements Exception {
  const VideoUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
