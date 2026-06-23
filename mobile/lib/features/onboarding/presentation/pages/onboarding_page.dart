import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      imageAsset: 'assets/images/onbroad1.png',
      kicker: 'An toàn thụ động',
      headline: 'Biết sớm khi người thân có dấu hiệu té ngã',
      subtitle:
          'AI theo dõi tư thế và chuyển động bất thường qua camera, không cần người cao tuổi đeo hay bấm thiết bị.',
    ),
    _OnboardingContent(
      imageAsset: 'assets/images/onbroad2.png',
      kicker: 'Cảnh báo tức thì',
      headline: 'Nhận thông báo ngay khi có sự cố',
      subtitle:
          'Khi phát hiện tình huống nghiêm trọng, AnNhà gửi cảnh báo đến điện thoại kèm mức độ, thời gian và vị trí.',
    ),
    _OnboardingContent(
      imageAsset: 'assets/images/onbroad3.png',
      kicker: 'Xem lại & xác nhận',
      headline: 'Kiểm tra sự kiện trước khi hành động',
      subtitle:
          'Bạn có thể xem lại đoạn ghi sự kiện, xác nhận đó là té ngã thật hoặc bỏ qua nếu chỉ là cảnh báo nhầm.',
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
      duration: const Duration(milliseconds: 340),
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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Bỏ qua'),
                ),
              ),
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
              const SizedBox(height: 16),
              _DotIndicator(count: _pages.length, selectedIndex: _pageIndex),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(isFinalPage ? 'Bắt đầu' : 'Tiếp tục'),
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
    required this.imageAsset,
    required this.kicker,
    required this.headline,
    required this.subtitle,
  });

  final String imageAsset;
  final String kicker;
  final String headline;
  final String subtitle;
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.content});

  final _OnboardingContent content;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isShort = constraints.maxHeight < 590;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PageIllustration(imageAsset: content.imageAsset),
                SizedBox(height: isShort ? 22 : 30),
                Text(
                  content.kicker,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  content.headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontSize: isShort ? 24 : 29,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: Text(
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PageIllustration extends StatelessWidget {
  const _PageIllustration({required this.imageAsset});

  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: Image.asset(
                imageAsset,
                width: 150,
                height: 150,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
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
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: index == selectedIndex ? 18 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: index == selectedIndex
                  ? AppColors.primary
                  : AppColors.mutedText,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
