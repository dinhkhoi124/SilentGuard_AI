// lib/features/home/domain/entities/event_feedback_label.dart

enum EventFeedbackLabel {
  correct('correct'),
  incorrect('incorrect'),
  uncertain('uncertain');

  const EventFeedbackLabel(this.value);

  final String value;
}
