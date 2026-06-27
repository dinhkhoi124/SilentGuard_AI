import 'dart:io';

import 'package:mobile/features/video_upload/domain/entities/video_upload_result.dart';

abstract interface class VideoUploadRepository {
  Future<VideoUploadResult> uploadVideo({
    required String householdId,
    required File videoFile,
  });
}
