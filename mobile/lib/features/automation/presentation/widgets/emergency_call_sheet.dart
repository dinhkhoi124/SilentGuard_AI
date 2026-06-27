// lib/features/automation/presentation/widgets/emergency_call_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/automation/domain/entities/emergency_contact.dart';
import 'package:mobile/features/automation/presentation/cubit/emergency_contacts_cubit.dart';
import 'package:mobile/features/automation/presentation/cubit/emergency_contacts_state.dart';
import 'package:mobile/injection_container.dart';
import 'package:mobile/core/services/phone_dialer_service.dart';

class EmergencyCallSheet extends StatelessWidget {
  const EmergencyCallSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EmergencyCallSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EmergencyContactsCubit>()..loadContacts(),
      child: const _CallSheetContent(),
    );
  }
}

class _CallSheetContent extends StatelessWidget {
  const _CallSheetContent();

  Future<void> _makeCall(BuildContext context, String phoneNumber) async {
    final dialerService = sl<PhoneDialerService>();
    final success = await dialerService.openDialer(phoneNumber);

    if (!success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở ứng dụng gọi điện trên thiết bị này.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.outlineVariant
                  : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          BlocBuilder<EmergencyContactsCubit, EmergencyContactsState>(
            builder: (context, state) {
              if (state is EmergencyContactsLoading && state.contacts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                );
              }

              if (state.contacts.isEmpty) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.surfaceContainerHighest
                            : const Color(0xFFF0F4F8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.contact_phone_outlined,
                        size: 40,
                        color: isDark
                            ? theme.colorScheme.primary
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có liên hệ khẩn cấp',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? theme.colorScheme.onSurface
                            : AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hãy thêm số điện thoại để gọi nhanh khi có sự cố.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? theme.colorScheme.onSurfaceVariant
                            : AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/emergency-contacts');
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Thêm liên hệ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Gọi khẩn cấp',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? theme.colorScheme.onSurface
                            : AppColors.darkText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Chọn người bạn muốn gọi để kiểm tra tình trạng ngay.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? theme.colorScheme.onSurfaceVariant
                            : AppColors.mutedText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.contacts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final contact = state.contacts[index];
                      return _CallContactCard(
                        contact: contact,
                        onCall: () => _makeCall(context, contact.phoneNumber),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/emergency-contacts');
                      },
                      child: const Text(
                        'Quản lý liên hệ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CallContactCard extends StatelessWidget {
  const _CallContactCard({required this.contact, required this.onCall});

  final EmergencyContact contact;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? theme.colorScheme.outlineVariant : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : const Color(0xFFF0F4F8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              color: isDark ? theme.colorScheme.primary : AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? theme.colorScheme.onSurface
                        : AppColors.darkText,
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
          FilledButton.icon(
            onPressed: onCall,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Gọi'),
          ),
        ],
      ),
    );
  }
}
