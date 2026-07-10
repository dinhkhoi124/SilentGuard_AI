import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class EventDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const EventDateHeaderDelegate({required this.title});

  final String title;

  @override
  double get minExtent => 32;

  @override
  double get maxExtent => 32;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.background,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant EventDateHeaderDelegate oldDelegate) {
    return title != oldDelegate.title;
  }
}
