import 'package:equatable/equatable.dart';

class VideoUploadResult extends Equatable {
  const VideoUploadResult({required this.uploadId});

  final String uploadId;

  @override
  List<Object?> get props => [uploadId];
}
