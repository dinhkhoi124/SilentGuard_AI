import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/router/auth_notifier.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/injection_container.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _controller;
  int _pageIndex = 0;

static const _pages = [
  _OnboardingContent(
    icon: Iconsax.video_play,
    accentIcon: Iconsax.user_tick,
    kicker: 'Phát hiện té ngã tự động',
    headline: 'An tâm khi người thân ở một mình',
    subtitle:
        'AI theo dõi tư thế và phát hiện nguy cơ té ngã mà không cần đeo thiết bị.',
    detail: 'Camera phân tích chuyển động trong phòng.',
  ),
  _OnboardingContent(
    icon: Iconsax.notification_status,
    accentIcon: Iconsax.video_octagon,
    kicker: 'Cảnh báo kịp thời',
    headline: 'Biết ngay khi có sự cố',
    subtitle:
        'Nhận thông báo theo mức độ nguy hiểm và xem nhanh đoạn clip sự kiện.',
    detail: 'Cảnh báo hiển thị mức độ và cho phép xem lại nhanh.',
  ),
  _OnboardingContent(
    icon: Iconsax.shield_tick,
    accentIcon: Iconsax.tick_circle,
    kicker: 'Bảo vệ quyền riêng tư',
    headline: 'An toàn hơn, riêng tư hơn',
    subtitle:
        'Video được xử lý ẩn danh. Bạn luôn là người xác nhận và quyết định hành động.',
    detail: 'Mọi cảnh báo đều cần được người thân kiểm tra và xác nhận.',
  ),
];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await sl<AuthNotifier>().completeOnboarding();
    if (!mounted) return;
    context.go('/welcome');
  }

  void _continue() {
    if (_pageIndex == _pages.length - 1) {
      unawaited(_finish());
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFinalPage = _pageIndex == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (index) => setState(() => _pageIndex = index),
                  itemBuilder: (context, index) {
                    return _OnboardingSlide(content: _pages[index]);
                  },
                ),
              ),
              const SizedBox(height: 14),
              _DotIndicator(count: _pages.length, selectedIndex: _pageIndex),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _continue,
                  child: Text(isFinalPage ? 'Get started' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingContent {
  const _OnboardingContent({
    required this.icon,
    required this.accentIcon,
    required this.kicker,
    required this.headline,
    required this.subtitle,
    required this.detail,
  });

  final IconData icon;
  final IconData accentIcon;
  final String kicker;
  final String headline;
  final String subtitle;
  final String detail;
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.content});

  final _OnboardingContent content;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isShort = constraints.maxHeight < 560;
        final illustrationSize = (constraints.maxHeight * 0.34).clamp(
          154.0,
          238.0,
        );

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OnboardingIllustration(
                  icon: content.icon,
                  accentIcon: content.accentIcon,
                  detail: content.detail,
                  size: illustrationSize,
                  compact: isShort,
                ),
                SizedBox(height: isShort ? 22 : 34),
                Text(
                  content.kicker,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  content.headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontSize: isShort ? 23 : 27,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  content.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({
    required this.icon,
    required this.accentIcon,
    required this.detail,
    required this.size,
    required this.compact,
  });

  final IconData icon;
  final IconData accentIcon;
  final String detail;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: SizedBox.square(dimension: size * 0.92),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 28,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: SizedBox.square(
              dimension: size * 0.58,
              child: Icon(icon, color: AppColors.primary, size: size * 0.28),
            ),
          ),
          Positioned(
            right: size * 0.16,
            top: size * 0.14,
            child: _FloatingIcon(icon: accentIcon, size: size * 0.22),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 210 : 250),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.darkText,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Text(
                      detail,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: size,
        child: Icon(icon, color: Colors.white, size: size * 0.48),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.selectedIndex});

  final int count;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: index == selectedIndex ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: index == selectedIndex
                  ? AppColors.primary
                  : AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}
