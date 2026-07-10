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
            'Danh sách thành viên',
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
              'Những người đang tham gia vào gia đình này',
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
                  final members = state.members;

                  return CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final member = members[index];
                          final hasName = member.fullName.trim().isNotEmpty;
                          final displayName = hasName
                              ? member.fullName
                              : member.email;
                          final displayEmail = hasName ? member.email : '';

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
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: isDark
                                      ? theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                      : const Color(0xFFF1F5F9),
                                  child: Text(
                                    displayName[0].toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? theme.colorScheme.onSurface
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (member.role == 'owner') ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Chủ hộ',
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: displayEmail.isNotEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          displayEmail,
                                          style: TextStyle(
                                            color: isDark
                                                ? theme
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                : const Color(0xFF64748B),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }, childCount: members.length),
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
