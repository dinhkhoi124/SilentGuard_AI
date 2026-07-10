// lib/features/home/presentation/cubit/event_feedback_state.dart

import 'package:mobile/features/home/domain/entities/event_feedback_label.dart';

sealed class EventFeedbackState {
  const EventFeedbackState();
}

final class EventFeedbackInitial extends EventFeedbackState {
  const EventFeedbackInitial();
}

final class EventFeedbackSubmitting extends EventFeedbackState {
  const EventFeedbackSubmitting({required this.label, this.note});

  final EventFeedbackLabel label;
  final String? note;
}

final class EventFeedbackSuccess extends EventFeedbackState {
  const EventFeedbackSuccess({required this.label, this.note, this.warning});

  final EventFeedbackLabel label;
  final String? note;
  final String? warning;
}

final class EventFeedbackFailure extends EventFeedbackState {
  const EventFeedbackFailure({
    required this.message,
    required this.label,
    this.note,
  });

  final String message;
  final EventFeedbackLabel label;
  final String? note;
}
