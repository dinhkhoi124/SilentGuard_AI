import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class EventHistorySkeleton extends StatefulWidget {
  const EventHistorySkeleton({super.key, this.count = 5});
  final int count;

  @override
  State<EventHistorySkeleton> createState() => _EventHistorySkeletonState();
}

class _EventHistorySkeletonState extends State<EventHistorySkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          children: List.generate(
            widget.count,
            (index) => _SkeletonCard(animationValue: _controller.value),
          ),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.animationValue});
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    // Generate a sliding gradient from -1.0 to 2.0 based on animation value (0 to 1).
    final beginX = -1.0 + (animationValue * 3);
    final endX = beginX + 1.0;

    return Container(
      height: 76,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(
            width: 36,
            height: 36,
            shape: BoxShape.circle,
            beginX: beginX,
            endX: endX,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _ShimmerBox(
                  width: 140,
                  height: 16,
                  borderRadius: BorderRadius.circular(4),
                  beginX: beginX,
                  endX: endX,
                ),
                const SizedBox(height: 8),
                _ShimmerBox(
                  width: 200,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                  beginX: beginX,
                  endX: endX,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.beginX,
    required this.endX,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
  });

  final double width;
  final double height;
  final double beginX;
  final double endX;
  final BoxShape shape;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment(beginX, 0),
          end: Alignment(endX, 0),
          colors: const [
            Color(0xFFEBEBEB),
            Color(0xFFF4F4F4),
            Color(0xFFEBEBEB),
          ],
        ),
      ),
    );
  }
}
