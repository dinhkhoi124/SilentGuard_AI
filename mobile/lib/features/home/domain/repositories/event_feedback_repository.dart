// lib/features/home/domain/repositories/event_feedback_repository.dart

import 'package:dartz/dartz.dart';
import 'package:mobile/features/home/domain/entities/event_feedback_label.dart';

abstract interface class EventFeedbackRepository {
  Future<Either<String, void>> submitFeedback({
    required String eventId,
    required EventFeedbackLabel label,
    String? note,
  });
}
