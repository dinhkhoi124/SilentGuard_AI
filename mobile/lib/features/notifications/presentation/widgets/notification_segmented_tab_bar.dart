import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/core/utils/app_colors.dart';

class NotificationSegmentedTabBar extends StatelessWidget
    implements PreferredSizeWidget {
  final TabController controller;
  final int unreadAlerts;
  final int unreadInvites;

  const NotificationSegmentedTabBar({
    super.key,
    required this.controller,
    required this.unreadAlerts,
    required this.unreadInvites,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        4,
        AppSpacing.pagePadding,
        12,
      ),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: controller,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          labelColor: AppColors.surface,
          labelStyle: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          unselectedLabelColor: AppColors.darkText,
          unselectedLabelStyle: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          splashBorderRadius: BorderRadius.circular(12),
          tabs: [
            Tab(
              child: Badge(
                isLabelVisible: unreadAlerts > 0,
                label: Text(unreadAlerts.toString()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text('General'),
                ),
              ),
            ),
            Tab(
              child: Badge(
                isLabelVisible: unreadInvites > 0,
                label: Text(unreadInvites.toString()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text('Smart Home'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);
}
