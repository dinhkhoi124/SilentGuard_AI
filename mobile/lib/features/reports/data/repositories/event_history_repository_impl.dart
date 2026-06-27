import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/reports/data/datasources/event_history_remote_datasource.dart';
import 'package:mobile/features/reports/domain/entities/event_history_page.dart';
import 'package:mobile/features/reports/domain/repositories/event_history_repository.dart';

class EventHistoryRepositoryImpl implements EventHistoryRepository {
  const EventHistoryRepositoryImpl(this._remoteDataSource);

  final EventHistoryRemoteDataSource _remoteDataSource;

  @override
  Future<Either<String, EventHistoryPage>> getHistory({
    required String householdId,
    int page = 1,
    int pageSize = 20,
    String? severity,
    String? room,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final model = await _remoteDataSource.getHistory(
        householdId: householdId,
        page: page,
        pageSize: pageSize,
        severity: severity,
        room: room,
        fromDate: fromDate,
        toDate: toDate,
      );
      return Right(model.toEntity());
    } on ApiException catch (e) {
      if (e.kind == ApiExceptionKind.unauthorized ||
          e.kind == ApiExceptionKind.forbidden) {
        return Left('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      return Left(e.message);
    } on TimeoutException {
      return const Left(
        'Không thể kết nối máy chủ. Kết nối quá thời gian chờ.',
      );
    } on SocketException {
      return const Left('Không thể kết nối mạng. Vui lòng kiểm tra kết nối.');
    } on http.ClientException {
      return const Left('Không thể kết nối mạng. Vui lòng kiểm tra kết nối.');
    } catch (_) {
      return const Left('Lỗi không xác định. Vui lòng thử lại.');
    }
  }
}
