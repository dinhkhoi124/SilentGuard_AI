// lib/features/home/domain/usecases/submit_event_feedback.dart

import 'package:dartz/dartz.dart';
import 'package:mobile/features/home/domain/entities/event_feedback_label.dart';
import 'package:mobile/features/home/domain/repositories/event_feedback_repository.dart';

class SubmitEventFeedbackParams {
  const SubmitEventFeedbackParams({
    required this.eventId,
    required this.label,
    this.note,
  });

  final String eventId;
  final EventFeedbackLabel label;
  final String? note;
}

class SubmitEventFeedback {
  const SubmitEventFeedback(this.repository);

  final EventFeedbackRepository repository;

  Future<Either<String, void>> call(SubmitEventFeedbackParams params) {
    return repository.submitFeedback(
      eventId: params.eventId,
      label: params.label,
      note: params.note,
    );
  }
}
