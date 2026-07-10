import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

// Hiển thị giao diện chờ tải kết nối với hiệu ứng "Scan line" chạy dọc.
class RtmpLoadingPanel extends StatefulWidget {
  const RtmpLoadingPanel({super.key});

  @override
  State<RtmpLoadingPanel> createState() => _RtmpLoadingPanelState();
}

class _RtmpLoadingPanelState extends State<RtmpLoadingPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  // Dọn dẹp bộ đếm hoạt ảnh (animation controller) khi huỷ widget
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          if (!disableAnimations)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ScanLinePainter(
                    progress: _controller.value,
                    color: AppColors.primary,
                  ),
                  child: Container(),
                );
              },
            ),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 1.5,
                ),
                SizedBox(height: 12),
                Text(
                  'Đang kết nối...',
                  style: TextStyle(
                    color: Colors.white70,
                    letterSpacing: 1.5,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Vẽ nền lưới và đường line chạy ngang trên màn hình chờ tải
class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    // Grid background
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (var i = 0.0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (var i = 0.0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Scan line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0;

    final rect = Rect.fromLTWH(0, y - 10, size.width, 20);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        color.withValues(alpha: 0.5),
        Colors.transparent,
      ],
    ).createShader(rect);

    final fillPaint = Paint()..shader = gradient;

    canvas.drawRect(rect, fillPaint);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
