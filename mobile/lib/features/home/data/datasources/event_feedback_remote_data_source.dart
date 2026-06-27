// lib/features/home/data/datasources/event_feedback_remote_data_source.dart

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/home/domain/entities/event_feedback_label.dart';

abstract interface class EventFeedbackRemoteDataSource {
  Future<void> submitFeedback({
    required String eventId,
    required EventFeedbackLabel label,
    String? note,
  });
}

class EventFeedbackRemoteDataSourceImpl
    implements EventFeedbackRemoteDataSource {
  const EventFeedbackRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> submitFeedback({
    required String eventId,
    required EventFeedbackLabel label,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'label': label.value,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    await _apiClient.postObject(
      '/api/events/${Uri.encodeComponent(eventId)}/feedback',
      body,
    );
  }
}
