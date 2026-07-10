import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

// Hiển thị huy hiệu "LIVE" nhấp nháy cho người dùng biết luồng đang trực tiếp.
class RtmpLiveBadge extends StatefulWidget {
  const RtmpLiveBadge({super.key, required this.isLive});

  // Có đang phát trực tiếp không
  final bool isLive;

  @override
  State<RtmpLiveBadge> createState() => _RtmpLiveBadgeState();
}

class _RtmpLiveBadgeState extends State<RtmpLiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isLive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RtmpLiveBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive && !oldWidget.isLive) {
      _controller.repeat();
    } else if (!widget.isLive && oldWidget.isLive) {
      _controller.stop();
      _controller.reset();
    }
  }

  // Dọn dẹp animation controller để tránh rò rỉ bộ nhớ khi huỷ widget
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLive) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _PulsePainter(progress: _controller.value),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: const BoxDecoration(
          color: AppColors.badgeRed,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: const Text(
          '● LIVE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

// Vẽ vòng tròn sóng âm (ripple) phía sau huy hiệu
class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.height;

    final paint = Paint()
      ..color = AppColors.badgeRed.withValues(alpha: 1.0 - progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Vòng tròn to dần và mờ đi theo progress
    canvas.drawCircle(center, baseRadius + (baseRadius * progress), paint);
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
