import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/auth/domain/entities/app_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_event.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_state.dart';
import 'package:mobile/injection_container.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _logoutDialogVisible = false;

  @override
  void dispose() {
    _logoutDialogVisible = false;
    super.dispose();
  }

  void _showLogoutDialog() {
    if (_logoutDialogVisible || !mounted) return;
    _logoutDialogVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LogoutProgressDialog(),
    );
  }

  void _hideLogoutDialog() {
    if (!_logoutDialogVisible || !mounted) return;
    _logoutDialogVisible = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final authRepository = sl<AuthRepository>();

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthLoading) {
          _showLogoutDialog();
          return;
        }

        if (state is AuthSignedOut) {
          _hideLogoutDialog();
          return;
        }

        if (state is AuthFailure) {
          _hideLogoutDialog();
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
      child: StreamBuilder<AppUser?>(
        stream: authRepository.authStateChanges(),
        initialData: authRepository.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                sliver: SliverList.list(
                  children: [
                    _ProfileHeader(user: user),
                    const SizedBox(height: 28),
                    const _SectionLabel('Cài đặt chung'),
                    const SizedBox(height: 6),
                    const _AccountMenuTile(
                      icon: Iconsax.home,
                      title: 'Quản lý nhà',
                    ),
                    const _AccountMenuTile(
                      icon: Iconsax.microphone,
                      title: 'Trợ lý giọng nói',
                    ),
                    const _AccountMenuTile(
                      icon: Iconsax.notification,
                      title: 'Thông báo',
                    ),
                    const _AccountMenuTile(
                      icon: Iconsax.shield_tick,
                      title: 'Tài khoản & bảo mật',
                    ),
                    const _AccountMenuTile(
                      icon: Iconsax.link,
                      title: 'Tài khoản liên kết',
                    ),
                    _AccountMenuTile(
                      icon: Iconsax.eye,
                      title: 'Giao diện ứng dụng',
                      onTap: () => context.push('/app-appearance'),
                    ),
                    const _AccountMenuTile(
                      icon: Iconsax.setting_2,
                      title: 'Cài đặt bổ sung',
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel('Hỗ trợ'),
                    const SizedBox(height: 6),
                    const _AccountMenuTile(
                      icon: Iconsax.chart_2,
                      title: 'Dữ liệu & phân tích',
                    ),
                    const _AccountMenuTile(
                      icon: Iconsax.document_text,
                      title: 'Trợ giúp & hỗ trợ',
                    ),
                    const SizedBox(height: 12),
                    const _LogoutTile(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final name = _displayName(user);
    final email = user?.email?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _Avatar(user: user, displayName: name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email == null || email.isEmpty ? 'Chưa có email' : email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.darkText,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(AppUser? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) return localPart;
    }

    return 'Người dùng SlientGuard';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.displayName});

  final AppUser? user;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoUrl?.trim();
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.lightBlue,
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    return CircleAvatar(
      radius: 32,
      backgroundColor: AppColors.lightBlue,
      child: Text(
        _initials(displayName),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _AccountMenuTile extends StatelessWidget {
  const _AccountMenuTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Icon(icon, color: AppColors.darkText, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.darkText,
              size: 25,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile();

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthBloc, bool>(
      (bloc) => bloc.state is AuthLoading,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isLoading
          ? null
          : () => context.read<AuthBloc>().add(const AuthSignOutRequested()),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Icon(
                Iconsax.logout,
                color: AppColors.destructive.withValues(
                  alpha: isLoading ? 0.55 : 1,
                ),
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đăng xuất',
                style: TextStyle(
                  color: AppColors.destructive.withValues(
                    alpha: isLoading ? 0.55 : 1,
                  ),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutProgressDialog extends StatelessWidget {
  const _LogoutProgressDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const SizedBox.square(
                  dimension: 48,
                  child: Icon(
                    Iconsax.logout,
                    color: AppColors.destructive,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Đang đăng xuất',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'SlientGuard đang kết thúc phiên làm việc của bạn.',
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(
                  minHeight: 5,
                  color: AppColors.destructive,
                  backgroundColor: AppColors.border,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
