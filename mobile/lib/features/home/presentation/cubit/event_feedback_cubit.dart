// lib/features/home/presentation/cubit/event_feedback_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/home/domain/entities/event_feedback_label.dart';
import 'package:mobile/features/home/domain/usecases/submit_event_feedback.dart';
import 'package:mobile/features/home/presentation/cubit/event_feedback_state.dart';

class EventFeedbackCubit extends Cubit<EventFeedbackState> {
  EventFeedbackCubit(
    this._submitEventFeedback, {
    required this.eventId,
    EventFeedbackState? initialState,
  }) : super(initialState ?? const EventFeedbackInitial());

  final SubmitEventFeedback _submitEventFeedback;
  final String eventId;

  Future<void> submit({required EventFeedbackLabel label, String? note}) async {
    emit(EventFeedbackSubmitting(label: label, note: note));

    final result = await _submitEventFeedback(
      SubmitEventFeedbackParams(eventId: eventId, label: label, note: note),
    );

    result.fold(
      (message) => emit(
        EventFeedbackFailure(message: message, label: label, note: note),
      ),
      (_) => emit(EventFeedbackSuccess(label: label, note: note)),
    );
  }

  Future<void> retry() async {
    final currentState = state;
    if (currentState is EventFeedbackFailure) {
      await submit(label: currentState.label, note: currentState.note);
    }
  }
}
