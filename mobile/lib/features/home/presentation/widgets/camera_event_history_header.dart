// lib/features/home/presentation/widgets/camera_event_history_header.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';

class CameraEventHistoryHeader extends StatelessWidget {
  const CameraEventHistoryHeader({
    super.key,
    this.selectedDate,
    this.onCalendarTap,
  });

  final DateTime? selectedDate;
  final VoidCallback? onCalendarTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Lịch sử sự kiện',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.calendar_search),
                    color: AppColors.mutedText,
                    onPressed: onCalendarTap,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  if (selectedDate != null)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),

              const Text(
                'Lọc theo ngày',
                style: TextStyle(fontSize: 13, color: AppColors.mutedText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
