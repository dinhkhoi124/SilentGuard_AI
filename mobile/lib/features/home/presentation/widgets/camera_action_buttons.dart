// lib/features/home/presentation/widgets/camera_action_buttons.dart

import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

import 'package:mobile/features/automation/presentation/widgets/emergency_call_sheet.dart';
import 'package:mobile/features/household_invite/presentation/widgets/invite_management_sheet.dart';

class CameraActionButtons extends StatelessWidget {
  const CameraActionButtons({
    super.key,
    required this.monitoringIcon,
    required this.monitoringLabel,
    this.onMonitoringTap,
    this.monitoringLoading = false,
    this.monitoringActive = false,
  });

  final IconData monitoringIcon;
  final String monitoringLabel;
  final VoidCallback? onMonitoringTap;
  final bool monitoringLoading;
  final bool monitoringActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionButton(
            icon: Icons.phone,
            label: 'Gọi khẩn cấp',
            onTap: () => EmergencyCallSheet.show(context),
          ),
          const _ActionButton(icon: Icons.textsms, label: 'Nhắn tin'),
          _ActionButton(
            icon: Icons.people,
            label: 'Người nhận\ncảnh báo',
            onTap: () => InviteManagementSheet.show(context),
          ),
          _ActionButton(
            icon: monitoringIcon,
            label: monitoringLabel,
            onTap: onMonitoringTap,
            isLoading: monitoringLoading,
            isActive: monitoringActive,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              height: 95,
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.lightBlue : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.32)
                      : Colors.grey.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: isActive ? 0.1 : 0.035,
                    ),
                    blurRadius: isActive ? 14 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 28,
                    child: Center(
                      child: isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.primary,
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Icon(
                                icon,
                                key: ValueKey(icon),
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    height: 30,
                    width: double.infinity,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          label,
                          key: ValueKey(label),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
