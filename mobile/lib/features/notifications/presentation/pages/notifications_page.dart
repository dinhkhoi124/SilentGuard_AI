import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';
import 'package:mobile/features/household_invite/presentation/cubit/pending_invites_cubit.dart';
import 'package:mobile/features/household_invite/presentation/cubit/pending_invites_state.dart';
import 'package:mobile/core/widgets/app_empty_state.dart';
import 'package:mobile/features/notifications/presentation/widgets/notification_segmented_tab_bar.dart';
import 'package:mobile/injection_container.dart' as di;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Listen to tab changes to update "Đánh dấu đã đọc" state if needed
    _tabController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationsCubit>().refreshFromLocalAndSyncPendingAlerts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final alertNotifications = state.notifications
            .where((n) => n.type != 'household_invite')
            .toList();
        final inviteNotifications = state.notifications
            .where((n) => n.type == 'household_invite')
            .toList();

        final unreadAlerts = alertNotifications.where((n) => !n.isRead).length;
        final unreadInvites = inviteNotifications
            .where((n) => !n.isRead)
            .length;

        final hasUnreadInCurrentTab =
            (_tabController.index == 0 && unreadAlerts > 0) ||
            (_tabController.index == 1 && unreadInvites > 0);

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: const Text('Thông báo'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.pop(),
              tooltip: 'Quay lại',
            ),
            actions: [
              TextButton(
                onPressed: hasUnreadInCurrentTab
                    ? () {
                        if (_tabController.index == 0) {
                          for (final n in alertNotifications) {
                            if (!n.isRead) {
                              context.read<NotificationsCubit>().markRead(n.id);
                            }
                          }
                        } else if (_tabController.index == 1) {
                          for (final n in inviteNotifications) {
                            if (!n.isRead) {
                              context.read<NotificationsCubit>().markRead(n.id);
                            }
                          }
                        }
                      }
                    : null,
                child: const Text('Đánh dấu đã đọc'),
              ),
            ],
            bottom: NotificationSegmentedTabBar(
              controller: _tabController,
              unreadAlerts: unreadAlerts,
              unreadInvites: unreadInvites,
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList(context, alertNotifications, false),
                _buildNotificationList(context, inviteNotifications, true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    List<NotificationAlert> notifications,
    bool isInvite,
  ) {
    if (notifications.isEmpty) {
      return _EmptyNotifications(
        icon: isInvite ? Iconsax.people : Iconsax.notification,
        title: isInvite ? 'Không có lời mời nào' : 'Chưa có cảnh báo té ngã',
        subtitle: isInvite
            ? 'Các lời mời tham gia gia đình sẽ xuất hiện tại đây.'
            : 'Khi hệ thống phát hiện sự cố, cảnh báo sẽ được hiển thị tại đây.',
      );
    }

    final grouped = _groupNotificationsByDate(notifications);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        10,
        AppSpacing.pagePadding,
        28,
      ),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final item = grouped[index];
        if (item is String) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
              ],
            ),
          );
        } else if (item is NotificationAlert) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: isInvite
                ? _InviteNotificationCard(notification: item)
                : _NotificationCard(
                    notification: item,
                    onTap: () => _handleNotificationTap(context, item),
                  ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  List<dynamic> _groupNotificationsByDate(
    List<NotificationAlert> notifications,
  ) {
    final Map<String, List<NotificationAlert>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final n in notifications) {
      final date = DateTime(
        n.receivedAt.year,
        n.receivedAt.month,
        n.receivedAt.day,
      );
      String key;
      if (date == today) {
        key = 'Hôm nay';
      } else if (date == yesterday) {
        key = 'Hôm qua';
      } else {
        key =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
      groups.putIfAbsent(key, () => []).add(n);
    }

    final result = <dynamic>[];
    groups.forEach((key, list) {
      result.add(key);
      result.addAll(list);
    });
    return result;
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final NotificationAlert notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _severityColor(notification);

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.75),
                  ),
                ),
                child: Icon(
                  _severityIcon(notification),
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.darkText,
                          fontWeight: notification.isRead
                              ? FontWeight.w700
                              : FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.displayBody,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatReceivedAt(notification.receivedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!notification.isRead) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 9, height: 9),
                      ),
                      const SizedBox(width: 14),
                    ],
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

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(icon: icon, title: title, message: subtitle);
  }
}

class _InviteNotificationCard extends StatelessWidget {
  const _InviteNotificationCard({required this.notification});

  final NotificationAlert notification;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<PendingInvitesCubit>(),
      child: BlocConsumer<PendingInvitesCubit, PendingInvitesState>(
        listener: (context, state) {
          if (state is RespondSuccess &&
              state.inviteRequestId == notification.inviteRequestId) {
            if (state.action == 'accepted') {
              di.sl<SessionRepository>().provisionSession();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Bạn đã tham gia ${notification.householdName ?? 'gia đình'}. Camera và thông báo đã được bật.',
                  ),
                ),
              );
            }
          }
        },
        builder: (context, state) {
          final isResponding =
              state is RespondingToInvite &&
              state.inviteRequestId == notification.inviteRequestId;
          final successState =
              state is RespondSuccess &&
                  state.inviteRequestId == notification.inviteRequestId
              ? state
              : null;

          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? theme.colorScheme.surfaceContainerHighest
                              : const Color(0xFFE8F0FE),
                        ),
                        child: const Icon(
                          Icons.home_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.darkText,
                                fontWeight: notification.isRead
                                    ? FontWeight.w700
                                    : FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notification.displayBody,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.mutedText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _NotificationCard._formatReceivedAt(
                                notification.receivedAt,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!notification.isRead)
                        Padding(
                          padding: const EdgeInsets.only(top: 5, left: 10),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox(width: 9, height: 9),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (successState != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 66),
                      child: Text(
                        successState.action == 'accepted'
                            ? 'Đã chấp nhận'
                            : 'Đã từ chối',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedText,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(left: 66),
                      child: Row(
                        children: [
                          OutlinedButton(
                            onPressed: isResponding
                                ? null
                                : () {
                                    context
                                        .read<PendingInvitesCubit>()
                                        .respondToInvite(
                                          notification.inviteRequestId ?? '',
                                          'declined',
                                        );
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(
                                color: AppColors.border.withValues(alpha: 0.8),
                              ),
                            ),
                            child: const Text(
                              'Từ chối',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: isResponding
                                ? null
                                : () {
                                    context
                                        .read<PendingInvitesCubit>()
                                        .respondToInvite(
                                          notification.inviteRequestId ?? '',
                                          'accepted',
                                        );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isResponding
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Chấp nhận',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
