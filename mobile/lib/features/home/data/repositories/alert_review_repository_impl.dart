import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:mobile/core/error/exceptions.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/home/data/datasources/alert_review_remote_data_source.dart';
import 'package:mobile/features/home/domain/entities/alert_review_feedback.dart';
import 'package:mobile/features/home/domain/repositories/alert_review_repository.dart';

class AlertReviewRepositoryImpl implements AlertReviewRepository {
  const AlertReviewRepositoryImpl(this._remoteDataSource);

  final AlertReviewRemoteDataSource _remoteDataSource;

  @override
  Future<Either<String, void>> reviewAlert(AlertReviewFeedback feedback) async {
    try {
      await _remoteDataSource.reviewAlert(
        eventId: feedback.eventId,
        action: feedback.action,
        note: feedback.note,
        clipTimestamp: feedback.clipTimestamp,
      );
      return const Right(null);
    } on ApiException catch (error) {
      return Left(error.message);
    } on NoInternetException catch (error) {
      return Left(error.message);
    } catch (_) {
      return const Left('Lỗi không xác định. Vui lòng thử lại.');
    }
  }
}
