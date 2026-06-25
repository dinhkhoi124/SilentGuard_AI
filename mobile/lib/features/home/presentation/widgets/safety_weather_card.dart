import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/domain/entities/weather_info.dart';

class _SafetyWeatherDisplayData {
  const _SafetyWeatherDisplayData({
    required this.statusTitle,
    required this.statusMessage,
    required this.cameraLabel,
    required this.alertLabel,
    required this.weatherLabel,
    required this.hasCameras,
  });

  final String statusTitle;
  final String statusMessage;
  final String cameraLabel;
  final String alertLabel;
  final String weatherLabel;
  final bool hasCameras;
}

class SafetyWeatherCard extends StatefulWidget {
  const SafetyWeatherCard({
    super.key,
    required this.weather,
    required this.totalCameras,
    required this.onlineCameras,
  });

  final WeatherInfo? weather;
  final int totalCameras;
  final int onlineCameras;

  @override
  State<SafetyWeatherCard> createState() => _SafetyWeatherCardState();
}

class _SafetyWeatherCardState extends State<SafetyWeatherCard>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  late final AnimationController _floatController;
  late final Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final entranceCurve = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(entranceCurve);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(entranceCurve);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _floatAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, -0.04),
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0, -0.04),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 50,
      ),
    ]).animate(_floatController);

    _entranceController.forward();
    _floatController.repeat();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  _SafetyWeatherDisplayData get _displayData {
    final hasCameras = widget.totalCameras > 0;

    // We don't need weatherLabel in _displayData anymore as it's handled in the UI
    if (!hasCameras) {
      return const _SafetyWeatherDisplayData(
        statusTitle: 'Chưa bắt đầu giám sát',
        statusMessage: 'Thêm camera để bảo vệ người thân tốt hơn.',
        cameraLabel: '0 thiết bị',
        alertLabel: 'Chưa có dữ liệu',
        weatherLabel: '',
        hasCameras: false,
      );
    } else {
      return _SafetyWeatherDisplayData(
        statusTitle: 'Nhà đang được giám sát',
        statusMessage: 'Các camera đang theo dõi an toàn cho người thân.',
        cameraLabel: '${widget.onlineCameras}/${widget.totalCameras} camera',
        alertLabel: 'Sẵn sàng cảnh báo',
        weatherLabel: '',
        hasCameras: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final display = _displayData;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      theme.colorScheme.surfaceContainerHighest,
                      theme.colorScheme.surfaceContainer,
                    ]
                  : [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              // Decorative background blobs
              Positioned(
                right: -40,
                top: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _AnimatedSafetyIcon(
                                    floatAnimation: _floatAnimation,
                                    isProtected: display.hasCameras,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'TRẠNG THÁI AN TOÀN',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                display.statusTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                display.statusMessage,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.weather != null) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: _WeatherSummaryCapsule(
                              weather: widget.weather!,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SafetyMetricChip(
                          icon: Iconsax.camera,
                          label: display.cameraLabel,
                          isActive: display.hasCameras,
                        ),
                        _SafetyMetricChip(
                          icon: display.hasCameras
                              ? Iconsax.shield_tick
                              : Iconsax.shield_cross,
                          label: display.alertLabel,
                          isActive: display.hasCameras,
                        ),
                        if (widget.weather != null &&
                            widget.weather!.humidity > 0)
                          _SafetyMetricChip(
                            icon: Iconsax.drop,
                            label:
                                '${widget.weather!.humidity.toStringAsFixed(0)}% độ ẩm',
                            isActive: true,
                          ),
                        if (widget.weather != null &&
                            widget.weather!.windSpeed > 0)
                          _SafetyMetricChip(
                            icon: Iconsax.wind,
                            label:
                                '${widget.weather!.windSpeed.toStringAsFixed(1)} m/s gió',
                            isActive: true,
                          ),
                        if (widget.weather != null && widget.weather!.aqi > 0)
                          _SafetyMetricChip(
                            icon: Iconsax.health,
                            label: '${widget.weather!.aqi} AQI',
                            isActive: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedSafetyIcon extends StatelessWidget {
  const _AnimatedSafetyIcon({
    required this.floatAnimation,
    required this.isProtected,
    this.size = 64,
  });

  final Animation<Offset> floatAnimation;
  final bool isProtected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final innerSize = size * 0.75;
    final iconSize = size * 0.45;
    final dotSize = size * 0.2;

    return SlideTransition(
      position: floatAnimation,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          Container(
            width: innerSize,
            height: innerSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Icon(
              isProtected ? Icons.shield_rounded : Icons.gpp_maybe_rounded,
              color: isProtected ? AppColors.safe : AppColors.primary,
              size: iconSize,
            ),
          ),
          if (isProtected)
            Positioned(
              right: size * 0.03,
              top: size * 0.03,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.safe,
                  border: Border.all(
                    color: Colors.white,
                    width: dotSize * 0.15,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SafetyMetricChip extends StatelessWidget {
  const _SafetyMetricChip({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  final IconData icon;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherSummaryCapsule extends StatelessWidget {
  const _WeatherSummaryCapsule({required this.weather});
  final WeatherInfo weather;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.cloud_sunny, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${weather.temperature.toStringAsFixed(0)}°C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            weather.city.isNotEmpty ? weather.city : 'Hà Nội',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            weather.condition,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
