import 'package:mobile/features/reports/domain/entities/event_history_item.dart';

sealed class EventHistoryState {
  const EventHistoryState();
}

final class EventHistoryInitial extends EventHistoryState {
  const EventHistoryInitial();
}

final class EventHistoryLoading extends EventHistoryState {
  const EventHistoryLoading();
}

final class EventHistoryLoaded extends EventHistoryState {
  const EventHistoryLoaded({required this.items, this.isRefreshing = false});

  final List<EventHistoryItem> items;

  /// True while a silent background refresh is in progress.
  /// The existing [items] remain visible during refresh.
  final bool isRefreshing;

  EventHistoryLoaded copyWith({
    List<EventHistoryItem>? items,
    bool? isRefreshing,
  }) {
    return EventHistoryLoaded(
      items: items ?? this.items,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

final class EventHistoryEmpty extends EventHistoryState {
  const EventHistoryEmpty();
}

final class EventHistoryError extends EventHistoryState {
  const EventHistoryError(this.message);

  final String message;
}
