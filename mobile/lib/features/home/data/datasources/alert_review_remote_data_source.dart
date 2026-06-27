import 'package:mobile/core/network/api_client.dart';

abstract interface class AlertReviewRemoteDataSource {
  Future<void> reviewAlert({
    required String eventId,
    required String action,
    String? note,
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
    double? clipTimestamp,
  }) async {
    final body = <String, dynamic>{
      'action': action,
      'note': ?note,
      'clip_timestamp': ?clipTimestamp,
    };

    await _apiClient.patch(
      '/api/alerts/${Uri.encodeComponent(eventId)}/review',
      body,
    );
  }
}
