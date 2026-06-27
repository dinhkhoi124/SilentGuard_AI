import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/reports/data/models/event_history_model.dart';

abstract interface class EventHistoryRemoteDataSource {
  Future<EventHistoryResponseModel> getHistory({
    required String householdId,
    int page = 1,
    int pageSize = 20,
    String? severity,
    String? room,
    String? fromDate,
    String? toDate,
  });
}

class EventHistoryRemoteDataSourceImpl implements EventHistoryRemoteDataSource {
  const EventHistoryRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<EventHistoryResponseModel> getHistory({
    required String householdId,
    int page = 1,
    int pageSize = 20,
    String? severity,
    String? room,
    String? fromDate,
    String? toDate,
  }) async {
    // Build query params map; only include optional fields when non-null.
    // ApiClient.getObjectWithQuery uses Uri.replace(queryParameters: …)
    // so every value is automatically percent-encoded.
    final params = <String, String>{
      'household_id': householdId,
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };
    if (severity != null) params['severity'] = severity;
    if (room != null) params['room'] = room;
    if (fromDate != null) params['from_date'] = fromDate;
    if (toDate != null) params['to_date'] = toDate;

    final json = await _apiClient.getObjectWithQuery(
      '/api/events/history',
      params,
    );

    return EventHistoryResponseModel.fromJson(json);
  }
}
