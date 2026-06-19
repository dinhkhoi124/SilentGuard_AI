// lib/features/home/presentation/widgets/weather_card.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/domain/entities/weather_info.dart';

class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key, required this.weather});

  final WeatherInfo? weather;

  @override
  Widget build(BuildContext context) {
    final weather = this.weather;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -54,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          const Positioned(right: 18, top: 22, child: _WeatherArtwork()),
          Padding(
            padding: const EdgeInsets.all(20),
            child: weather == null
                ? const _WeatherUnavailable()
                : _WeatherContent(weather: weather),
          ),
        ],
      ),
    );
  }
}

class _WeatherContent extends StatelessWidget {
  const _WeatherContent({required this.weather});

  final WeatherInfo weather;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${weather.temperature.toStringAsFixed(0)}°C',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          weather.city,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.86),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          weather.condition,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            _WeatherStat(
              icon: Iconsax.cloud,
              value: '${weather.aqi}',
              label: 'AQI',
            ),
            _WeatherStat(
              icon: Iconsax.drop,
              value: '${weather.humidity.toStringAsFixed(1)}%',
              label: 'Độ ẩm',
            ),
            _WeatherStat(
              icon: Iconsax.wind,
              value: '${weather.windSpeed.toStringAsFixed(1)} m/s',
              label: 'Gió',
            ),
          ],
        ),
      ],
    );
  }
}

class _WeatherUnavailable extends StatelessWidget {
  const _WeatherUnavailable();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Iconsax.cloud_cross, color: Colors.white, size: 34),
        const SizedBox(height: 12),
        const Text(
          'Chưa có dữ liệu thời tiết',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Kết nối API thời tiết để hiển thị nhiệt độ, AQI và độ ẩm tại đây.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _WeatherStat extends StatelessWidget {
  const _WeatherStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
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

class _WeatherArtwork extends StatelessWidget {
  const _WeatherArtwork();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 122,
      height: 105,
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 0,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE8A3), Color(0xFFFFC857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC857).withValues(alpha: 0.35),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 2,
            bottom: 8,
            child: CustomPaint(
              size: const Size(112, 66),
              painter: _CloudPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = const Color(0xFF2749C4).withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final cloudPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white, Color(0xFFDDE6FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(22, 59)
      ..cubicTo(3, 59, 1, 34, 20, 29)
      ..cubicTo(23, 8, 51, 2, 63, 21)
      ..cubicTo(80, 13, 99, 24, 98, 41)
      ..cubicTo(116, 43, 116, 63, 98, 64)
      ..lineTo(22, 64)
      ..close();

    canvas
      ..drawPath(path.shift(const Offset(0, 5)), shadowPaint)
      ..drawPath(path, cloudPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
