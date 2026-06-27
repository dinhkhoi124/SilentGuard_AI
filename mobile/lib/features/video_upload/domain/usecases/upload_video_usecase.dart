import 'dart:io';

import 'package:mobile/features/video_upload/domain/entities/video_upload_result.dart';
import 'package:mobile/features/video_upload/domain/repositories/video_upload_repository.dart';

class UploadVideoUseCase {
  const UploadVideoUseCase(this._repository);

  final VideoUploadRepository _repository;

  Future<VideoUploadResult> call({
    required String householdId,
    required File videoFile,
  }) {
    return _repository.uploadVideo(
      householdId: householdId,
      videoFile: videoFile,
    );
  }
}
