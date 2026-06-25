// lib/features/automation/presentation/pages/emergency_contacts_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/automation/domain/entities/emergency_contact.dart';
import 'package:mobile/features/automation/presentation/cubit/emergency_contacts_cubit.dart';
import 'package:mobile/features/automation/presentation/cubit/emergency_contacts_state.dart';
import 'package:mobile/core/widgets/app_empty_state.dart';
import 'package:mobile/features/automation/presentation/widgets/emergency_contact_form_sheet.dart';
import 'package:mobile/injection_container.dart';

class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EmergencyContactsCubit>()..loadContacts(),
      child: const _EmergencyContactsView(),
    );
  }
}

class _EmergencyContactsView extends StatelessWidget {
  const _EmergencyContactsView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? theme.colorScheme.surface
          : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDark ? theme.colorScheme.onSurface : AppColors.darkText,
        ),
        title: Text(
          'Liên hệ khẩn cấp',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? theme.colorScheme.onSurface : AppColors.darkText,
          ),
        ),
      ),
      body: BlocConsumer<EmergencyContactsCubit, EmergencyContactsState>(
        listener: (context, state) {
          if (state is EmergencyContactsError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        builder: (context, state) {
          if (state is EmergencyContactsLoading && state.contacts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final contacts = state.contacts;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Text(
                    'Các số này chỉ được lưu trên thiết bị này và dùng cho nút Gọi khẩn cấp.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : AppColors.mutedText,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              if (contacts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: const AppEmptyState(
                    icon: Icons.contact_phone_outlined,
                    title: 'Chưa có liên hệ khẩn cấp',
                    message:
                        'Thêm người thân để họ có thể nhận cảnh báo và hỗ trợ khi cần.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final contact = contacts[index];
                      return _ContactCard(contact: contact);
                    }, childCount: contacts.length),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddContactSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Thêm liên hệ',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _openAddContactSheet(BuildContext context) async {
    final cubit = context.read<EmergencyContactsCubit>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EmergencyContactFormSheet(cubit: cubit),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? theme.colorScheme.outlineVariant : AppColors.border,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest
                      : const Color(0xFFF0F4F8),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  contact.priorityOrder.toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? theme.colorScheme.primary
                        : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? theme.colorScheme.onSurface
                            : AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 4),
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
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: isDark
                      ? theme.colorScheme.onSurfaceVariant
                      : AppColors.mutedText,
                  size: 20,
                ),
                onPressed: () => _openEditSheet(context),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFE53935),
                  size: 20,
                ),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditSheet(BuildContext context) async {
    final cubit = context.read<EmergencyContactsCubit>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          EmergencyContactFormSheet(cubit: cubit, existingContact: contact),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final cubit = context.read<EmergencyContactsCubit>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xóa liên hệ?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Liên hệ này sẽ không còn xuất hiện trong danh sách gọi khẩn cấp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.mutedText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Xóa',
              style: TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await cubit.deleteContact(contact.id);
    }
  }
}
