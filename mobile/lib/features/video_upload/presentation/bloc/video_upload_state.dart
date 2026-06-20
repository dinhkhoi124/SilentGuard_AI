part of 'video_upload_bloc.dart';

sealed class VideoUploadState extends Equatable {
  const VideoUploadState();

  @override
  List<Object?> get props => [];
}

class VideoUploadInitial extends VideoUploadState {
  const VideoUploadInitial();
}

class VideoUploadLoading extends VideoUploadState {
  const VideoUploadLoading();
}

class VideoUploadSuccess extends VideoUploadState {
  const VideoUploadSuccess();
}

class VideoUploadFailure extends VideoUploadState {
  const VideoUploadFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
