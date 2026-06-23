import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_state.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationsCubit>().refreshFromLocalAndSyncPendingAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            return Column(
              children: [
                _NotificationsHeader(unreadCount: state.unreadCount),
                Expanded(
                  child: state.notifications.isEmpty
                      ? const _EmptyNotifications()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                          itemBuilder: (context, index) {
                            final notification = state.notifications[index];
                            return _NotificationCard(
                              notification: notification,
                              onTap: () =>
                                  _handleNotificationTap(context, notification),
                            );
                          },
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemCount: state.notifications.length,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    NotificationAlert notification,
  ) {
    context.read<NotificationsCubit>().markRead(notification.id);

    final cameraId = notification.cameraId?.trim() ?? '';
    if (cameraId.isNotEmpty) {
      context.push('/camera/${Uri.encodeComponent(cameraId)}');
      return;
    }

    final eventId = notification.eventId?.trim() ?? '';
    if (eventId.isNotEmpty) {
      // TODO: open event detail when the event review route is available.
    }
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                tooltip: 'Quay lại',
              ),
              Text(
                'Thông báo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: hasUnread
                    ? () => context.read<NotificationsCubit>().markAllRead()
                    : null,
                child: const Text('Đánh dấu đã đọc'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              hasUnread
                  ? 'Bạn có $unreadCount thông báo chưa đọc.'
                  : 'Tất cả thông báo đã được đọc.',
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final NotificationAlert notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _severityColor(notification);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: notification.isRead
                  ? AppColors.border.withValues(alpha: 0.55)
                  : accent.withValues(alpha: 0.25),
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _severityIcon(notification),
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.displayTitle,
                            style: TextStyle(
                              color: AppColors.darkText,
                              fontSize: 16,
                              height: 1.25,
                              fontWeight: notification.isRead
                                  ? FontWeight.w700
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: 8),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.badgeRed,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox(width: 9, height: 9),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      notification.displayBody,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 14,
                        height: 1.38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MetaPill(
                          icon: Iconsax.clock,
                          label: _formatReceivedAt(notification.receivedAt),
                        ),
                        _MetaPill(
                          icon: Iconsax.location,
                          label: notification.displayRoom,
                        ),
                        _SeverityBadge(
                          label: notification.displaySeverity,
                          color: accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _severityIcon(NotificationAlert notification) {
    switch ((notification.severity ?? notification.type ?? '').toUpperCase()) {
      case 'CRITICAL':
      case 'HIGH':
        return Iconsax.warning_2;
      case 'MEDIUM':
        return Iconsax.info_circle;
      default:
        return Iconsax.notification;
    }
  }

  static Color _severityColor(NotificationAlert notification) {
    switch ((notification.severity ?? notification.type ?? '').toUpperCase()) {
      case 'CRITICAL':
      case 'HIGH':
        return AppColors.badgeRed;
      case 'MEDIUM':
        return AppColors.warning;
      case 'LOW':
        return AppColors.safe;
      default:
        return AppColors.primary;
    }
  }

  static String _formatReceivedAt(DateTime receivedAt) {
    final difference = DateTime.now().difference(receivedAt);
    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
    if (difference.inDays < 1) return '${difference.inHours} giờ trước';
    if (difference.inDays < 7) return '${difference.inDays} ngày trước';
    return '${receivedAt.day.toString().padLeft(2, '0')}/'
        '${receivedAt.month.toString().padLeft(2, '0')}/'
        '${receivedAt.year}';
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedText),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Iconsax.notification,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có thông báo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.darkText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Các cảnh báo từ hệ thống sẽ xuất hiện tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
