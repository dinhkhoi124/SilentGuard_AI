import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';

class EmptyDevices extends StatelessWidget {
  const EmptyDevices({super.key, required this.onAddDevice});

  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 126,
          height: 116,
          child: CustomPaint(painter: _ClipboardPainter()),
        ),
        const SizedBox(height: 20),
        const Text(
          'No Devices',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          "You haven't added a device yet.",
          style: TextStyle(color: AppColors.mutedText, fontSize: 14),
        ),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: onAddDevice,
          icon: const Icon(Iconsax.add, size: 18),
          label: const Text('Add Device'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
      ..color = const Color(0xFFFFC857)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(87, 72), const Offset(106, 91), pencil);
    canvas.drawLine(const Offset(87, 72), const Offset(106, 91), stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
