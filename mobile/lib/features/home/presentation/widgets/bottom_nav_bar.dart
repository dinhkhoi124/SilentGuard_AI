// lib/features/home/presentation/widgets/bottom_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onUploadSelected,
    this.uploadDisabled = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onUploadSelected;
  final bool uploadDisabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? theme.colorScheme.outline.withValues(alpha: 0.65)
        : const Color(0xFFEEEEEE);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : AppColors.surface,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Iconsax.home,
                label: 'Trang chủ',
                active: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
              _NavItem(
                icon: Iconsax.task_square,
                label: 'Tự động',
                active: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
              _NavItem(
                icon: Icons.video_library_outlined,
                label: 'Gửi video',
                onTap: uploadDisabled ? null : onUploadSelected,
                disabled: uploadDisabled,
              ),
              _NavItem(
                icon: Iconsax.chart,
                label: 'Báo cáo',
                active: selectedIndex == 2,
                hasBadge: false, // TODO: set to true if there are new reports
                onTap: () => onSelected(2),
              ),
              _NavItem(
                icon: Iconsax.profile_circle,
                label: 'Tài khoản',
                active: selectedIndex == 3,
                onTap: () => onSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.hasBadge = false,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool hasBadge;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.mutedText;
    final activeColor = isDark ? theme.colorScheme.primary : AppColors.primary;
    final color = disabled
        ? mutedColor.withValues(alpha: 0.45)
        : active
        ? activeColor
        : mutedColor;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: !disabled,
        selected: active,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 3,
                margin: const EdgeInsets.only(bottom: 7),
                decoration: BoxDecoration(
                  color: active ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: color, size: 22),
                  if (hasBadge)
                    const Positioned(
                      right: -3,
                      top: -2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.badgeRed,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 8, height: 8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
