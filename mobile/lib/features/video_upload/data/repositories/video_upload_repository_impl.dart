import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:mobile/core/error/exceptions.dart';
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
    } on NoInternetException catch (error, stackTrace) {
      _logFailure(error, stackTrace);
      throw VideoUploadException(error.message);
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
