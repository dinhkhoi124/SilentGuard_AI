// lib/features/household_invite/presentation/widgets/invite_management_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';
import 'package:mobile/features/household_invite/presentation/cubit/invite_management_cubit.dart';
import 'package:mobile/features/household_invite/presentation/cubit/invite_management_state.dart';
import 'package:mobile/features/household_invite/presentation/widgets/invite_dialog.dart';
import 'package:mobile/injection_container.dart';

class InviteManagementSheet extends StatelessWidget {
  const InviteManagementSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const InviteManagementSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final householdId = sl<SessionRepository>().currentHouseholdId;

    return BlocProvider(
      create: (_) =>
          sl<InviteManagementCubit>()..loadMembers(householdId ?? ''),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) =>
            _SheetContent(scrollController: scrollController),
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final role = sl<SessionRepository>().currentHousehold?.role ?? 'member';
    final isOwner = role == 'owner';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
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
          Text(
            'Người nhận cảnh báo',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? theme.colorScheme.onSurface : AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
            ),
            child: Text(
              'Thành viên sẽ nhận thông báo khi phát hiện té ngã',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? theme.colorScheme.onSurfaceVariant
                    : AppColors.mutedText,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BlocBuilder<InviteManagementCubit, InviteManagementState>(
              builder: (context, state) {
                if (state is InviteManagementLoading ||
                    state is InviteManagementInitial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is InviteManagementError) {
                  return Center(
                    child: Text(
                      state.message,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  );
                }

                if (state is InviteManagementLoaded) {
                  final inContacts =
                      state.members.where((m) => m.isInContacts).toList()..sort(
                        (a, b) => (a.contactsPriority ?? 999).compareTo(
                          b.contactsPriority ?? 999,
                        ),
                      );
                  final notInContacts = state.members
                      .where((m) => !m.isInContacts)
                      .toList();

                  return CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      if (inContacts.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.pagePadding,
                              16,
                              AppSpacing.pagePadding,
                              8,
                            ),
                            child: Text(
                              'Danh sách ưu tiên',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: isDark
                                    ? theme.colorScheme.primary
                                    : AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      SliverReorderableList(
                        itemCount: inContacts.length,
                        onReorder: (oldIndex, newIndex) {
                          if (!isOwner) {
                            return;
                          }
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final member = inContacts[oldIndex];
                          final householdId =
                              sl<SessionRepository>().currentHouseholdId ?? '';
                          context.read<InviteManagementCubit>().reorderContacts(
                            member.userId,
                            newIndex + 1,
                            householdId,
                          );
                          // A proper implementation would update the local list immediately for UI responsiveness,
                          // but cubit re-fetches for simplicity.
                        },
                        itemBuilder: (context, index) {
                          final member = inContacts[index];
                          return Padding(
                            key: ValueKey(member.userId),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.pagePadding,
                              vertical: 6,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? theme.colorScheme.surfaceContainer
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.border.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: isDark
                                        ? theme
                                              .colorScheme
                                              .surfaceContainerHighest
                                        : const Color(0xFFF0F4F8),
                                    child: Text(
                                      member.fullName.isNotEmpty
                                          ? member.fullName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? theme.colorScheme.onSurface
                                            : AppColors.darkText,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    member.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  subtitle: Text(
                                    member.role == 'owner'
                                        ? 'Chủ gia đình'
                                        : 'Thành viên',
                                    style: TextStyle(
                                      color: AppColors.mutedText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: AppColors.warning,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${member.contactsPriority ?? index + 1}',
                                              style: const TextStyle(
                                                color: AppColors.warning,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isOwner) ...[
                                        const SizedBox(width: 12),
                                        const Icon(
                                          Icons.drag_indicator,
                                          color: AppColors.mutedText,
                                          size: 20,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (isOwner && notInContacts.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.pagePadding,
                              24,
                              AppSpacing.pagePadding,
                              8,
                            ),
                            child: Text(
                              'Thành viên khác',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: isDark
                                    ? theme.colorScheme.primary
                                    : AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (isOwner)
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final member = notInContacts[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pagePadding,
                                vertical: 6,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? theme.colorScheme.surfaceContainer
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.border.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: isDark
                                        ? theme
                                              .colorScheme
                                              .surfaceContainerHighest
                                        : const Color(0xFFF0F4F8),
                                    child: Text(
                                      member.fullName.isNotEmpty
                                          ? member.fullName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? theme.colorScheme.onSurface
                                            : AppColors.darkText,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    member.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  subtitle: Text(
                                    member.email,
                                    style: const TextStyle(
                                      color: AppColors.mutedText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: FilledButton.tonalIcon(
                                    onPressed: () {
                                      final householdId =
                                          sl<SessionRepository>()
                                              .currentHouseholdId ??
                                          '';
                                      context
                                          .read<InviteManagementCubit>()
                                          .addToAlerts(
                                            member.userId,
                                            householdId,
                                          );
                                    },
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text(
                                      'Thêm',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }, childCount: notInContacts.length),
                        ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          if (isOwner)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                16,
                AppSpacing.pagePadding,
                MediaQuery.paddingOf(context).bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final cubit = context.read<InviteManagementCubit>();
                    InviteDialog.show(context, cubit);
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 20),
                  label: const Text(
                    'Mời thêm thành viên',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
        ],
      ),
    );
  }
}
