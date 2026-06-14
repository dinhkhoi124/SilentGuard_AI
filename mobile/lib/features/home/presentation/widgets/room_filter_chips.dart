// lib/features/home/presentation/widgets/room_filter_chips.dart

import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class RoomFilterChips extends StatelessWidget {
  const RoomFilterChips({
    super.key,
    required this.selectedRoom,
    required this.onSelected,
  });

  static const rooms = [
    'All Rooms',
    'Living Room',
    'Bedroom',
    'Kitchen',
    'Bathroom',
  ];
  static const roomLabels = {
    'All Rooms': 'Tất cả phòng',
    'Living Room': 'Phòng khách',
    'Bedroom': 'Phòng ngủ',
    'Kitchen': 'Nhà bếp',
    'Bathroom': 'Phòng tắm',
  };

  final String selectedRoom;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: rooms.map((room) {
          final selected = room == selectedRoom;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Semantics(
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelected(room),
                borderRadius: BorderRadius.circular(99),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    roomLabels[room] ?? room,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.darkText,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
