// lib/features/home/data/repositories/event_feedback_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/home/data/datasources/event_feedback_remote_data_source.dart';
import 'package:mobile/features/home/domain/entities/event_feedback_label.dart';
import 'package:mobile/features/home/domain/repositories/event_feedback_repository.dart';

class EventFeedbackRepositoryImpl implements EventFeedbackRepository {
  const EventFeedbackRepositoryImpl(this._remoteDataSource);

  final EventFeedbackRemoteDataSource _remoteDataSource;

  @override
  Future<Either<String, void>> submitFeedback({
    required String eventId,
    required EventFeedbackLabel label,
    String? note,
  }) async {
    try {
      await _remoteDataSource.submitFeedback(
        eventId: eventId,
        label: label,
        note: note,
      );
      return const Right(null);
    } on ApiException catch (e) {
      if (e.kind == ApiExceptionKind.unauthorized) {
        return const Left('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }
      if (e.statusCode == 404) {
        return const Left(
          'Không tìm thấy sự kiện này. Có thể sự kiện đã bị xóa.',
        );
      }
      if (e.statusCode == 422) {
        return const Left('Dữ liệu gửi lên không hợp lệ.');
      }
      return Left(e.message);
    } catch (e) {
      return const Left('Không thể gửi phản hồi. Vui lòng kiểm tra mạng.');
    }
  }
}
