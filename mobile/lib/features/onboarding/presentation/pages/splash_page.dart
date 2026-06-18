import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmartifyBadge(),
                  SizedBox(height: 22),
                  Text(
                    'Smartify',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 54,
              child: Center(
                child: SizedBox.square(
                  dimension: 34,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartifyBadge extends StatelessWidget {
  const _SmartifyBadge();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _PentagonClipper(),
      child: Container(
        width: 112,
        height: 112,
        color: Colors.white,
        alignment: Alignment.center,
        child: const CustomPaint(
          size: Size(58, 58),
          painter: _SignalMarkPainter(),
        ),
      ),
    );
  }
}

class _PentagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final path = Path();
    for (var index = 0; index < 5; index++) {
      final angle = -math.pi / 2 + index * 2 * math.pi / 5;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _SignalMarkPainter extends CustomPainter {
  const _SignalMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height * 0.72);

    for (final radius in const [14.0, 25.0, 36.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 1.18,
        math.pi * 0.64,
        false,
        paint,
      );
    }

    canvas.drawCircle(center, 4.5, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
