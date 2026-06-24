// lib/features/home/presentation/widgets/camera_action_buttons.dart

import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

import 'package:mobile/features/automation/presentation/widgets/emergency_call_sheet.dart';

class CameraActionButtons extends StatelessWidget {
  const CameraActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionButton(
            icon: Icons.phone,
            label: 'Gọi cho người\nthân',
            onTap: () => EmergencyCallSheet.show(context),
          ),
          const _ActionButton(icon: Icons.textsms, label: 'Nhắn tin'),
          const _ActionButton(
            icon: Icons.people,
            label: 'Người nhận\ncảnh báo',
            badge: '3',
          ),
          const _ActionButton(
            icon: Icons.pause_circle,
            label: 'Tạm dừng\ngiám sát',
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
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                height: 95,
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
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
                        child: Icon(icon, color: AppColors.primary, size: 24),
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 30,
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Text(
                          label,
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
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
