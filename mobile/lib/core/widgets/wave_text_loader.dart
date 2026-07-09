import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class WaveTextLoader extends StatefulWidget {
  const WaveTextLoader({super.key});

  @override
  State<WaveTextLoader> createState() => _WaveTextLoaderState();
}

class _WaveTextLoaderState extends State<WaveTextLoader>
    with SingleTickerProviderStateMixin {
  static const _text = 'ĐANG TẢI...';

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final center = _controller.value;
          final start = (center - 0.32).clamp(0.0, 1.0);
          final end = (center + 0.32).clamp(0.0, 1.0);

          return Stack(
            alignment: Alignment.center,
            children: [
              Text(_text, style: _outlineStyle()),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0),
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0),
                    ],
                    stops: [start, center, end],
                  ).createShader(bounds);
                },
                child: const Text(_text, style: _filledStyle),
              ),
            ],
          );
        },
      ),
    );
  }

  TextStyle _outlineStyle() {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.primary,
    );
  }

  static const _filledStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );
}
