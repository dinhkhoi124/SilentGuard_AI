import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/core/theme/app_spacing.dart';
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
  void _showComingSoonSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Tính năng này sẽ sớm phát triển.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final authRepository = sl<AuthRepository>();

    return BlocListener<AuthBloc, AuthState>(
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
      child: StreamBuilder<AppUser?>(
        stream: authRepository.authStateChanges(),
        initialData: authRepository.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  8,
                  AppSpacing.pagePadding,
                  20,
                ),
                sliver: SliverList.list(
                  children: [
                    _ProfileHeader(user: user),
                    const SizedBox(height: 28),
                    const _SectionLabel('Cài đặt chung'),
                    const SizedBox(height: 6),
                    _AccountMenuTile(
                      icon: Iconsax.home,
                      title: 'Quản lý nhà',
                      onTap: () => _showComingSoonSnackBar(context),
                    ),
                    _AccountMenuTile(
                      icon: Iconsax.microphone,
                      title: 'Trợ lý giọng nói',
                      onTap: () => _showComingSoonSnackBar(context),
                    ),
                    _AccountMenuTile(
                      icon: Iconsax.notification,
                      title: 'Thông báo',
                      onTap: () => context.push('/notification-settings'),
                    ),
                    _AccountMenuTile(
                      icon: Iconsax.shield_tick,
                      title: 'Tài khoản & bảo mật',
                      onTap: () => _showComingSoonSnackBar(context),
                    ),
                    _AccountMenuTile(
                      icon: Iconsax.link,
                      title: 'Tài khoản liên kết',
                      onTap: () => _showComingSoonSnackBar(context),
                    ),
                    _AccountMenuTile(
                      icon: Iconsax.eye,
                      title: 'Giao diện ứng dụng',
                      onTap: () => context.push('/app-appearance'),
                    ),
                    _AccountMenuTile(
                      icon: Iconsax.setting_2,
                      title: 'Cài đặt bổ sung',
                      onTap: () => _showComingSoonSnackBar(context),
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel('Hỗ trợ'),
                    const SizedBox(height: 6),
                    _AccountMenuTile(
                      icon: Iconsax.chart_2,
                      title: 'Dữ liệu & phân tích',
                      onTap: () => _showComingSoonSnackBar(context),
                    ),
                    _AccountMenuTile(
                      icon: Iconsax.document_text,
                      title: 'Trợ giúp & hỗ trợ',
                      onTap: () => context.push('/help-support'),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? theme.colorScheme.surface : AppColors.surface;
    final nameColor = isDark ? theme.colorScheme.onSurface : AppColors.darkText;
    final emailColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.mutedText;
    final name = _displayName(user);
    final email = user?.email?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: nameColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email == null || email.isEmpty ? 'Chưa có email' : email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: emailColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: nameColor, size: 26),
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
    final theme = Theme.of(context);
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
        style: theme.textTheme.titleLarge?.copyWith(
          color: AppColors.primary,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.mutedText;
    final dividerColor = isDark
        ? theme.colorScheme.outline.withValues(alpha: 0.7)
        : AppColors.border;
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Divider(color: dividerColor)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final itemColor = isDark ? theme.colorScheme.onSurface : AppColors.darkText;
    final chevronColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.darkText;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            SizedBox(width: 42, child: Icon(icon, color: itemColor, size: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: itemColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: chevronColor, size: 25),
          ],
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile();

  Future<void> _confirmAndLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Có'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(const AuthSignOutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = context.select<AuthBloc, bool>(
      (bloc) => bloc.state is AuthLoading,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: isLoading ? null : () => _confirmAndLogout(context),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Iconsax.logout, color: AppColors.destructive, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đăng xuất',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.destructive.withValues(
                  alpha: isLoading ? 0.55 : 1,
                ),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
