part of 'video_upload_bloc.dart';

sealed class VideoUploadEvent extends Equatable {
  const VideoUploadEvent();

  @override
  List<Object?> get props => [];
}

class VideoUploadSubmitRequested extends VideoUploadEvent {
  const VideoUploadSubmitRequested();
}

class VideoUploadResetRequested extends VideoUploadEvent {
  const VideoUploadResetRequested();
}
