import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:mobile/core/utils/app_colors.dart';

class SilentGuardSplashScreen extends StatefulWidget {
  const SilentGuardSplashScreen({super.key});

  @override
  State<SilentGuardSplashScreen> createState() =>
      _SilentGuardSplashScreenState();
}

class _SilentGuardSplashScreenState extends State<SilentGuardSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _textFade;

  bool _introComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
          ),
        );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );

    _controller.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() => _introComplete = true);
      _controller.repeat(
        reverse: true,
        period: const Duration(milliseconds: 1500),
      );
    });
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoWidth = math.min(screenWidth * 0.72, 300.0);
    final logoHeight = logoWidth * 0.78;
    final pulseSize = math.min(screenWidth * 0.46, 180.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Color(0xFFF4F7FF),
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFFF5F8FC),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7FBFF), Color(0xFFEFF6FA), Color(0xFFF4F7FF)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: logoWidth,
                      height: math.max(logoHeight, 160),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final introValue = Curves.easeOut.transform(
                                _controller.value,
                              );
                              final pulseValue = _introComplete
                                  ? _controller.value
                                  : introValue;
                              final pulseOpacity = _introComplete
                                  ? 0.06 + ((1 - pulseValue) * 0.05)
                                  : introValue * 0.08;
                              final pulseScale = _introComplete
                                  ? 0.9 + (pulseValue * 0.25)
                                  : 0.9 + (introValue * 0.12);

                              return Transform.scale(
                                scale: pulseScale,
                                child: Container(
                                  width: pulseSize,
                                  height: pulseSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(
                                      alpha: pulseOpacity,
                                    ),
                                    border: Border.all(
                                      color: AppColors.primaryLight.withValues(
                                        alpha: pulseOpacity * 0.7,
                                      ),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          FadeTransition(
                            opacity: _introComplete
                                ? const AlwaysStoppedAnimation(1.0)
                                : _logoFade,
                            child: SlideTransition(
                              position: _introComplete
                                  ? const AlwaysStoppedAnimation(Offset.zero)
                                  : _logoSlide,
                              child: ScaleTransition(
                                scale: _introComplete
                                    ? const AlwaysStoppedAnimation(1.0)
                                    : _logoScale,
                                child: Image.asset(
                                  'assets/images/logo_app.png',
                                  width: logoWidth,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: _introComplete
                          ? const AlwaysStoppedAnimation(1.0)
                          : _textFade,
                      child: const Text(
                        'Âm thầm bảo vệ kết nối yêu thương',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF526173),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
