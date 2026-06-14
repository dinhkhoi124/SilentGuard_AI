import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: const SafeArea(
        top: false,
        child: Row(
          children: [
            _NavItem(icon: Iconsax.home, label: 'Home', active: true),
            _NavItem(icon: Iconsax.task_square, label: 'Smart'),
            _NavItem(icon: Iconsax.chart, label: 'Reports', hasBadge: true),
            _NavItem(icon: Iconsax.profile_circle, label: 'Account'),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.hasBadge = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.mutedText;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 34,
              height: 3,
              margin: const EdgeInsets.only(bottom: 7),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.transparent,
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
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
