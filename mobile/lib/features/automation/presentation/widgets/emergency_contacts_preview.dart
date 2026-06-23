import 'package:flutter/material.dart';
import 'package:mobile/core/utils/app_colors.dart';

class EmergencyContactsPreview extends StatelessWidget {
  const EmergencyContactsPreview({super.key, required this.onManageContacts});

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
              'Danh sách này sẽ được dùng khi cảnh báo mức cao không được phản hồi.',
              style: TextStyle(
                color: isDark
                    ? theme.colorScheme.onSurfaceVariant
                    : AppColors.mutedText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? theme.colorScheme.outline : AppColors.background,
          ),
          const _ContactPreviewTile(
            number: '1',
            name: 'Tôi',
            role: 'Người nhận cảnh báo đầu tiên',
          ),
          Divider(
            height: 1,
            indent: 64,
            color: isDark ? theme.colorScheme.outline : AppColors.background,
          ),
          const _ContactPreviewTile(
            number: '2',
            name: 'Anh Long',
            role: 'Gọi nếu không có phản hồi',
          ),
          Divider(
            height: 1,
            indent: 64,
            color: isDark ? theme.colorScheme.outline : AppColors.background,
          ),
          const _ContactPreviewTile(
            number: '3',
            name: 'Chị Liên',
            role: 'Dự phòng khi khẩn cấp',
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onManageContacts,
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
                child: const Text(
                  'Quản lý liên hệ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
  const _ContactPreviewTile({
    required this.number,
    required this.name,
    required this.role,
  });

  final String number;
  final String name;
  final String role;

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
              number,
              style: TextStyle(
                color: isDark
                    ? theme.colorScheme.onSurfaceVariant
                    : AppColors.mutedText,
                fontSize: 14,
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
                  name,
                  style: TextStyle(
                    color: isDark
                        ? theme.colorScheme.onSurface
                        : AppColors.darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: TextStyle(
                    color: isDark
                        ? theme.colorScheme.onSurfaceVariant
                        : AppColors.mutedText,
                    fontSize: 13,
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
