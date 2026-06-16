// lib/features/auth/presentation/widgets/app_logo.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const PentagonClipper(),
      child: const ColoredBox(
        color: AppColors.primary,
        child: SizedBox(
          width: 80,
          height: 80,
          child: Icon(Icons.wifi_rounded, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}

class PentagonClipper extends CustomClipper<Path> {
  const PentagonClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.shortestSide / 2;

    for (var index = 0; index < 5; index++) {
      final angle = (index * 72 - 90) * (pi / 180);
      final x = centerX + radius * cos(angle);
      final y = centerY + radius * sin(angle);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
