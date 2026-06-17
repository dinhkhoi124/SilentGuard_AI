import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit() : super(const NotificationsState());

  void receiveForegroundAlert(NotificationAlert alert) {
    emit(
      state.copyWith(
        unreadAlerts: _withAlert(alert),
        latestAlert: alert,
        latestDelivery: NotificationDelivery.foreground,
        revision: state.revision + 1,
      ),
    );
  }

  void receiveOpenedAlert(NotificationAlert alert) {
    emit(
      state.copyWith(
        latestAlert: alert,
        latestDelivery: NotificationDelivery.opened,
        revision: state.revision + 1,
      ),
    );
  }

  void markAllRead() {
    if (!state.hasUnread) return;
    emit(state.copyWith(unreadAlerts: const []));
  }

  List<NotificationAlert> _withAlert(NotificationAlert alert) {
    final eventId = alert.eventId;
    if (eventId == null || eventId.isEmpty) {
      return [alert, ...state.unreadAlerts];
    }

    return [
      alert,
      ...state.unreadAlerts.where((item) => item.eventId != eventId),
    ];
  }
}
