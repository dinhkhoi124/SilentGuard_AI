import 'package:equatable/equatable.dart';

class AlertReviewFeedback extends Equatable {
  const AlertReviewFeedback({
    required this.eventId,
    required this.action,
    required this.feedbackLabel,
    this.note,
    this.falsePositiveReason,
    this.clipTimestamp,
  });

  final String eventId;
  final String action;
  final String feedbackLabel;
  final String? note;
  final String? falsePositiveReason;
  final double? clipTimestamp;

  @override
  List<Object?> get props => [
    eventId,
    action,
    feedbackLabel,
    note,
    falsePositiveReason,
    clipTimestamp,
  ];
}
