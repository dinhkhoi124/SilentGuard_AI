// lib/features/household_invite/presentation/widgets/invite_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';
import 'package:mobile/features/household_invite/presentation/cubit/invite_management_cubit.dart';
import 'package:mobile/features/household_invite/presentation/cubit/invite_management_state.dart';
import 'package:mobile/injection_container.dart';

class InviteDialog extends StatefulWidget {
  const InviteDialog({super.key, required this.cubit});

  final InviteManagementCubit cubit;

  static void show(BuildContext context, InviteManagementCubit cubit) {
    showDialog(
      context: context,
      builder: (_) => InviteDialog(cubit: cubit),
    );
  }

  @override
  State<InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<InviteDialog> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _searchAndInvite() {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    final householdId = sl<SessionRepository>().currentHouseholdId ?? '';
    widget.cubit.inviteByEmail(email, householdId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocProvider.value(
      value: widget.cubit,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BlocConsumer<InviteManagementCubit, InviteManagementState>(
            listener: (context, state) {
              if (state is InviteEmailSuccess) {
                // Since requirements specify: "hide this button, show 'Đã gửi lời mời ✓' after success"
                // But also "On 'Gửi lời mời' success: close dialog, show SnackBar"
                // I will show snackbar and close dialog to respect the success state requirement.
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã gửi lời mời tới ${state.inviteeName}'),
                  ),
                );
              }
            },
            builder: (context, state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mời thành viên',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark
                          ? theme.colorScheme.onSurface
                          : AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Nhập email tài khoản SilentGuard',
                      hintStyle: TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? theme.colorScheme.surfaceContainerHighest
                          : const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (state is InviteEmailSearching)
                    const Center(child: CircularProgressIndicator())
                  else if (state is InviteEmailError)
                    Text(
                      state.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Hủy'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: state is InviteEmailSearching
                            ? null
                            : _searchAndInvite,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Tìm kiếm & Mời',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
