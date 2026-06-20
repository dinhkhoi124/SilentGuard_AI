// lib/features/home/presentation/widgets/camera_safety_status.dart

import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';

class CameraSafetyStatus extends StatelessWidget {
  const CameraSafetyStatus({
    super.key,
    required this.device,
    required this.updateTime,
  });

  final CameraDevice device;
  final String updateTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const _CircleIcon(
            icon: Icons.verified_user,
            backgroundColor: AppColors.infoBackground,
            iconColor: AppColors.primary,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trạng thái an toàn',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Hiện tại không có sự cố',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.safe,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cập nhật lúc $updateTime',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              const Icon(
                Icons.house_outlined,
                size: 52,
                color: Color.fromARGB(255, 200, 206, 248),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.safe,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.size,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: size / 2),
    );
  }
}
