import 'package:dartz/dartz.dart';
import 'package:mobile/features/home/domain/entities/alert_review_feedback.dart';

abstract interface class AlertReviewRepository {
  Future<Either<String, void>> reviewAlert(AlertReviewFeedback feedback);
}
