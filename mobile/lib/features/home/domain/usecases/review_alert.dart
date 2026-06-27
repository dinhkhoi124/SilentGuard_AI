import 'package:dartz/dartz.dart';
import 'package:mobile/features/home/domain/entities/alert_review_feedback.dart';
import 'package:mobile/features/home/domain/repositories/alert_review_repository.dart';

class ReviewAlert {
  const ReviewAlert(this.repository);

  final AlertReviewRepository repository;

  Future<Either<String, void>> call(AlertReviewFeedback feedback) {
    return repository.reviewAlert(feedback);
  }
}
