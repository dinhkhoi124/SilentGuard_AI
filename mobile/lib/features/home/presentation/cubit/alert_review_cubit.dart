import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/home/domain/entities/alert_review_feedback.dart';
import 'package:mobile/features/home/domain/usecases/review_alert.dart';

sealed class AlertReviewState {
  const AlertReviewState();
}

final class ReviewInitial extends AlertReviewState {
  const ReviewInitial();
}

final class ReviewSubmitting extends AlertReviewState {
  const ReviewSubmitting(this.feedback);

  final AlertReviewFeedback feedback;
}

final class ReviewSuccess extends AlertReviewState {
  const ReviewSuccess(this.feedback);

  final AlertReviewFeedback feedback;
}

final class ReviewFailure extends AlertReviewState {
  const ReviewFailure({required this.message, required this.feedback});

  final String message;
  final AlertReviewFeedback feedback;
}

class AlertReviewCubit extends Cubit<AlertReviewState> {
  AlertReviewCubit(this._reviewAlert, {AlertReviewState? initialState})
    : super(initialState ?? const ReviewInitial());

  final ReviewAlert _reviewAlert;

  Future<void> submit(AlertReviewFeedback feedback) async {
    _emitState(ReviewSubmitting(feedback));
    final result = await _reviewAlert(feedback);
    result.fold(
      (message) =>
          _emitState(ReviewFailure(message: message, feedback: feedback)),
      (_) => _emitState(ReviewSuccess(feedback)),
    );
  }

  Future<void> retry() async {
    final currentState = state;
    if (currentState is ReviewFailure) {
      await submit(currentState.feedback);
    }
  }

  void _emitState(AlertReviewState nextState) {
    emit(nextState);
  }
}
