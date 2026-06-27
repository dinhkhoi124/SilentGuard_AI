import 'dart:developer' as developer;
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';
import 'package:mobile/features/video_upload/domain/usecases/upload_video_usecase.dart';

part 'video_upload_event.dart';
part 'video_upload_state.dart';

class VideoUploadBloc extends Bloc<VideoUploadEvent, VideoUploadState> {
  VideoUploadBloc({
    required UploadVideoUseCase uploadVideoUseCase,
    required SessionRepository sessionRepository,
    ImagePicker? imagePicker,
  }) : _uploadVideoUseCase = uploadVideoUseCase,
       _sessionRepository = sessionRepository,
       _imagePicker = imagePicker ?? ImagePicker(),
       super(const VideoUploadInitial()) {
    on<VideoUploadSubmitRequested>(_onSubmitRequested);
    on<VideoUploadResetRequested>(
      (event, emit) => emit(const VideoUploadInitial()),
    );
  }

  final UploadVideoUseCase _uploadVideoUseCase;
  final SessionRepository _sessionRepository;
  final ImagePicker _imagePicker;

  Future<void> _onSubmitRequested(
    VideoUploadSubmitRequested event,
    Emitter<VideoUploadState> emit,
  ) async {
    if (state is VideoUploadLoading) return;

    emit(const VideoUploadLoading());
    try {
      final pickedVideo = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );
      if (pickedVideo == null) {
        emit(const VideoUploadInitial());
        return;
      }

      final householdId = _sessionRepository.currentHouseholdId;
      if (householdId == null || householdId.isEmpty) {
        developer.log(
          'Video upload failed because household id is missing.',
          name: 'VideoUploadBloc',
        );
        emit(const VideoUploadFailure('Missing household id.'));
        return;
      }

      await _uploadVideoUseCase(
        householdId: householdId,
        videoFile: File(pickedVideo.path),
      );
      emit(const VideoUploadSuccess());
    } catch (error, stackTrace) {
      developer.log(
        'Video upload flow failed.',
        name: 'VideoUploadBloc',
        error: error,
        stackTrace: stackTrace,
      );
      emit(VideoUploadFailure(error.toString()));
    }
  }
}
