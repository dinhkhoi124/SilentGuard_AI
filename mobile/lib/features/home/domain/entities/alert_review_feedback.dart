import 'package:equatable/equatable.dart';

class AlertReviewFeedback extends Equatable {
  const AlertReviewFeedback({
    required this.eventId,
    required this.action,
    this.note,
    this.clipTimestamp,
  });

  final String eventId;
  final String action;
  final String? note;
  final double? clipTimestamp;

  @override
  List<Object?> get props => [eventId, action, note, clipTimestamp];
}
