// lib/features/home/presentation/cubit/event_feedback_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/home/domain/entities/event_feedback_label.dart';
import 'package:mobile/features/home/domain/usecases/submit_event_feedback.dart';
import 'package:mobile/features/home/presentation/cubit/event_feedback_state.dart';

import 'package:mobile/features/home/domain/usecases/review_alert.dart';
import 'package:mobile/features/home/domain/entities/alert_review_feedback.dart';

class EventFeedbackCubit extends Cubit<EventFeedbackState> {
  EventFeedbackCubit(
    this._submitEventFeedback,
    this._reviewAlert, {
    required this.eventId,
    EventFeedbackState? initialState,
  }) : super(initialState ?? const EventFeedbackInitial());

  final SubmitEventFeedback _submitEventFeedback;
  final ReviewAlert _reviewAlert;
  final String eventId;

  String _mapLabelToAction(EventFeedbackLabel label) {
    return switch (label) {
      EventFeedbackLabel.correct => 'acknowledged',
      EventFeedbackLabel.incorrect => 'dismissed',
      EventFeedbackLabel.uncertain => 'acknowledged',
    };
  }

  Future<void> submit({required EventFeedbackLabel label, String? note}) async {
    emit(EventFeedbackSubmitting(label: label, note: note));

    // API 1: Review alert
    final reviewResult = await _reviewAlert(
      AlertReviewFeedback(eventId: eventId, action: _mapLabelToAction(label)),
    );

    await reviewResult.fold(
      (message) async {
        emit(EventFeedbackFailure(message: message, label: label, note: note));
      },
      (_) async {
        // API 2: Submit feedback
        final feedbackResult = await _submitEventFeedback(
          SubmitEventFeedbackParams(eventId: eventId, label: label, note: note),
        );

        feedbackResult.fold((message) {
          // Log silently and emit success with soft warning
          emit(
            EventFeedbackSuccess(
              label: label,
              note: note,
              warning: 'Lỗi gửi phản hồi AI: $message',
            ),
          );
        }, (_) => emit(EventFeedbackSuccess(label: label, note: note)));
      },
    );
  }

  Future<void> retry() async {
    final currentState = state;
    if (currentState is EventFeedbackFailure) {
      await submit(label: currentState.label, note: currentState.note);
    }
  }
}
