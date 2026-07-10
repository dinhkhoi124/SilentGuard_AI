import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/reports/data/models/daily_summary_model.dart';

abstract interface class DailySummaryRemoteDataSource {
  Future<DailySummaryModel> getDailySummary({
    required String date,
    required String householdId,
  });
}

class DailySummaryRemoteDataSourceImpl implements DailySummaryRemoteDataSource {
  const DailySummaryRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<DailySummaryModel> getDailySummary({
    required String date,
    required String householdId,
  }) async {
    final json = await _apiClient.getObjectWithQuery('/api/reports/daily', {
      'date': date,
      'household_id': householdId,
    });

    return DailySummaryModel.fromJson(json);
  }
}
