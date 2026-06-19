import 'package:mobile/core/network/api_client.dart';

abstract interface class AlertReviewRemoteDataSource {
  Future<void> reviewAlert({
    required String eventId,
    required String action,
    String? note,
    String? feedbackLabel,
    String? falsePositiveReason,
    double? clipTimestamp,
  });
}

class AlertReviewRemoteDataSourceImpl implements AlertReviewRemoteDataSource {
  const AlertReviewRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> reviewAlert({
    required String eventId,
    required String action,
    String? note,
    String? feedbackLabel,
    String? falsePositiveReason,
    double? clipTimestamp,
  }) async {
    // TODO: when backend adds CHECK constraint for 'uncertain' action,
    // update this mapping accordingly.
    final mappedAction = action == 'uncertain' ? 'dismissed' : action;
    final body = <String, dynamic>{
      'action': mappedAction,
      'note': ?note,
      'feedback_label': ?feedbackLabel,
      'false_positive_reason': ?falsePositiveReason,
      'clip_timestamp': ?clipTimestamp,
    };

    await _apiClient.patch(
      '/api/alerts/${Uri.encodeComponent(eventId)}/review',
      body,
    );
  }
}
