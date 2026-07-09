import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/automation/domain/entities/emergency_contact.dart';
import 'package:mobile/features/automation/presentation/cubit/emergency_contacts_cubit.dart';
import 'package:mobile/features/automation/presentation/cubit/emergency_contacts_state.dart';
import 'package:mobile/injection_container.dart';

class EmergencyContactsPreview extends StatelessWidget {
  const EmergencyContactsPreview({super.key, required this.onManageContacts});

  final VoidCallback onManageContacts;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EmergencyContactsCubit>()..loadContacts(),
      child: _PreviewContent(onManageContacts: onManageContacts),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.onManageContacts});

  final VoidCallback onManageContacts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: theme.colorScheme.outline) : null,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Danh sách này được dùng khi cảnh báo mức cao không được phản hồi.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? theme.colorScheme.onSurfaceVariant
                    : AppColors.mutedText,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? theme.colorScheme.outline : AppColors.background,
          ),
          BlocBuilder<EmergencyContactsCubit, EmergencyContactsState>(
            builder: (context, state) {
              if (state is EmergencyContactsLoading && state.contacts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (state.contacts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.contact_phone_outlined,
                          size: 32,
                          color: isDark
                              ? theme.colorScheme.outline
                              : AppColors.mutedText,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có liên hệ khẩn cấp',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? theme.colorScheme.onSurface
                                : AppColors.darkText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Thêm số điện thoại để gọi nhanh khi có sự cố.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? theme.colorScheme.onSurfaceVariant
                                : AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final topContacts = state.contacts.take(3).toList();
              return Column(
                children: [
                  for (int i = 0; i < topContacts.length; i++) ...[
                    _ContactPreviewTile(contact: topContacts[i]),
                    if (i < topContacts.length - 1)
                      Divider(
                        height: 1,
                        indent: 64,
                        color: isDark
                            ? theme.colorScheme.outline
                            : AppColors.background,
                      ),
                  ],
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await context.push('/emergency-contacts');
                  if (context.mounted) {
                    context.read<EmergencyContactsCubit>().loadContacts();
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? theme.colorScheme.primary
                      : AppColors.primary,
                  side: BorderSide(
                    color: isDark
                        ? theme.colorScheme.outline
                        : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Quản lý liên hệ',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactPreviewTile extends StatelessWidget {
  const _ContactPreviewTile({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHighest
                  : AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Text(
              contact.priorityOrder.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? theme.colorScheme.onSurfaceVariant
                    : AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isDark
                        ? theme.colorScheme.onSurface
                        : AppColors.darkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phoneNumber,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? theme.colorScheme.onSurfaceVariant
                        : AppColors.mutedText,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
