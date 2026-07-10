import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/error/exceptions.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/reports/data/datasources/daily_summary_remote_datasource.dart';
import 'package:mobile/features/reports/domain/entities/daily_summary.dart';
import 'package:mobile/features/reports/domain/repositories/daily_summary_repository.dart';

class DailySummaryRepositoryImpl implements DailySummaryRepository {
  const DailySummaryRepositoryImpl(this._remoteDataSource);

  final DailySummaryRemoteDataSource _remoteDataSource;

  @override
  Future<Either<DailySummaryFailure, DailySummary>> getDailySummary({
    required DateTime date,
    required String householdId,
  }) async {
    try {
      final model = await _remoteDataSource.getDailySummary(
        date: _formatDate(date),
        householdId: householdId,
      );
      if (!model.hasSummary) {
        return const Left(DailySummaryPendingFailure());
      }
      return Right(model.toEntity());
    } on ApiException catch (e) {
      if (e.kind == ApiExceptionKind.notFound) {
        return const Left(DailySummaryPendingFailure());
      }
      debugPrint('[DailySummaryRepository] API error: $e');
      if (e.kind == ApiExceptionKind.unauthorized ||
          e.kind == ApiExceptionKind.forbidden) {
        return const Left(
          DailySummaryErrorFailure(
            'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          ),
        );
      }
      return const Left(
        DailySummaryErrorFailure(
          'Chưa thể tải báo cáo AI. Vui lòng thử lại sau.',
        ),
      );
    } on NoInternetException catch (e) {
      debugPrint('[DailySummaryRepository] Network error: $e');
      return const Left(
        DailySummaryErrorFailure(
          'Không có kết nối mạng. Vui lòng kiểm tra và thử lại.',
        ),
      );
    } catch (e) {
      debugPrint('[DailySummaryRepository] Unexpected error: $e');
      return const Left(
        DailySummaryErrorFailure(
          'Đã có lỗi khi tải báo cáo AI. Vui lòng thử lại.',
        ),
      );
    }
  }

  static String _formatDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }
}
