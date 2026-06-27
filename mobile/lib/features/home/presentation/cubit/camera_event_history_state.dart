import 'package:mobile/features/reports/domain/entities/event_history_item.dart';

sealed class CameraEventHistoryState {
  const CameraEventHistoryState();
}

final class CameraEventHistoryInitial extends CameraEventHistoryState {
  const CameraEventHistoryInitial();
}

final class CameraEventHistoryLoading extends CameraEventHistoryState {
  const CameraEventHistoryLoading();
}

final class CameraEventHistoryLoaded extends CameraEventHistoryState {
  const CameraEventHistoryLoaded({required this.items});

  final List<EventHistoryItem> items;
}

final class CameraEventHistoryEmpty extends CameraEventHistoryState {
  const CameraEventHistoryEmpty();
}

final class CameraEventHistoryError extends CameraEventHistoryState {
  const CameraEventHistoryError(this.message);

  final String message;
}
