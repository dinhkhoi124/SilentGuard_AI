// lib/features/home/presentation/widgets/camera_event_history_header.dart

import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class CameraEventHistoryHeader extends StatelessWidget {
  const CameraEventHistoryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Lịch sử sự kiện',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          Row(
            children: [
              Icon(Icons.filter_list, size: 16, color: AppColors.mutedText),
              SizedBox(width: 4),
              Text(
                'Tất cả sự kiện',
                style: TextStyle(fontSize: 13, color: AppColors.mutedText),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: AppColors.mutedText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
