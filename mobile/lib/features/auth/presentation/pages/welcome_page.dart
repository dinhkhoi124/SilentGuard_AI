// lib/features/auth/presentation/pages/welcome_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile/features/auth/presentation/widgets/app_logo.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.destructive,
              ),
            );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 60).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const AppLogo(),
                          const SizedBox(height: 40),
                          const Text(
                            'Bắt đầu nào!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.darkText,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Hãy đăng nhập vào tài khoản của bạn',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _SocialButton(
                            type: _SocialType.google,
                            label: 'Tiếp tục với Google',
                            isLoading: isLoading,
                            onPressed: isLoading
                                ? null
                                : () => context.read<AuthBloc>().add(
                                    const AuthGoogleSignInRequested(),
                                  ),
                          ),
                          const SizedBox(height: 14),
                          const _SocialButton(
                            type: _SocialType.apple,
                            label: 'Tiếp tục với Apple',
                          ),
                          const SizedBox(height: 14),
                          const _SocialButton(
                            type: _SocialType.facebook,
                            label: 'Tiếp tục với Facebook',
                          ),
                          const SizedBox(height: 14),
                          const _SocialButton(
                            type: _SocialType.twitter,
                            label: 'Tiếp tục với Twitter',
                          ),
                          const SizedBox(height: 32),
                          _AuthButton(
                            label: 'Đăng ký',
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            onPressed: () => context.push('/signup'),
                          ),
                          const SizedBox(height: 12),
                          _AuthButton(
                            label: 'Đăng nhập',
                            backgroundColor: AppColors.lightBlue,
                            foregroundColor: AppColors.primary,
                            onPressed: () => context.push('/signin'),
                          ),
                          const Spacer(),
                          const SizedBox(height: 28),
                          const Text(
                            'Chính sách bảo mật · Điều khoản dịch vụ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFBDBDBD),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

enum _SocialType { google, apple, facebook, twitter }

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.type,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  final _SocialType type;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed ?? () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkText,
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Center(
                child: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : _SocialLogo(type: type),
              ),
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }
}

class _SocialLogo extends StatelessWidget {
  const _SocialLogo({required this.type});

  final _SocialType type;

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      _SocialType.google => const Icon(
        Icons.g_mobiledata_rounded,
        color: Color(0xFF4285F4),
        size: 30,
      ),
      _SocialType.apple => const Icon(
        Icons.apple,
        color: Colors.black,
        size: 25,
      ),
      _SocialType.facebook => const _LetterLogo(
        letter: 'f',
        background: Color(0xFF1877F2),
      ),
      _SocialType.twitter => const _LetterLogo(
        letter: 'X',
        background: Color(0xFF1DA1F2),
      ),
    };
  }
}

class _LetterLogo extends StatelessWidget {
  const _LetterLogo({required this.letter, required this.background});

  final String letter;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
