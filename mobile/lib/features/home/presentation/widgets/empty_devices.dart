// lib/features/home/presentation/widgets/empty_devices.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';

class EmptyDevices extends StatelessWidget {
  const EmptyDevices({super.key, required this.onAddDevice});

  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? theme.colorScheme.surface : AppColors.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 126,
              height: 116,
              child: CustomPaint(painter: _ClipboardPainter()),
            ),
            const SizedBox(height: 22),
            const Text(
              'Chưa có camera nào',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.darkText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy thêm camera để bắt đầu theo dõi an toàn cho người thân nhé.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddDevice,
              icon: const Icon(Iconsax.add, size: 18),
              label: const Text('Thêm thiết bị'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClipboardPainter extends CustomPainter {
  const _ClipboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final fill = Paint()..color = AppColors.lightBlue;
    final stroke = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final board = RRect.fromRectAndRadius(
      const Rect.fromLTWH(27, 16, 73, 91),
      const Radius.circular(13),
    );
    canvas
      ..drawOval(const Rect.fromLTWH(12, 92, 104, 15), shadow)
      ..drawRRect(board, fill)
      ..drawRRect(board, stroke);

    final clip = RRect.fromRectAndRadius(
      const Rect.fromLTWH(47, 9, 34, 18),
      const Radius.circular(7),
    );
    canvas
      ..drawRRect(clip, Paint()..color = Colors.white)
      ..drawRRect(clip, stroke)
      ..drawLine(const Offset(45, 48), const Offset(82, 48), stroke)
      ..drawLine(const Offset(45, 63), const Offset(72, 63), stroke)
      ..drawLine(const Offset(45, 78), const Offset(64, 78), stroke);

    final pencil = Paint()
      ..color = AppColors.warning
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(87, 72), const Offset(106, 91), pencil);
    canvas.drawLine(const Offset(87, 72), const Offset(106, 91), stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
