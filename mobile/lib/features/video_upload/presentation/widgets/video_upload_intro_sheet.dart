import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';

class VideoUploadIntroSheet extends StatelessWidget {
  const VideoUploadIntroSheet({super.key, required this.onChooseVideo});

  final VoidCallback onChooseVideo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        )
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Iconsax.video_play,
                    size: 36,
                    color: AppColors.primary,
                  ),
                  Positioned(
                    top: 18,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.surface
                            : AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.cpu5,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Gửi video cho AI phân tích',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isDark
                      ? theme.colorScheme.onSurface
                      : AppColors.darkText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Tải lên một video mô phỏng camera để hệ thống kiểm tra nguy cơ té ngã.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? theme.colorScheme.onSurfaceVariant
                      : AppColors.mutedText,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: const [
                  _StepTile(
                    stepNumber: '1',
                    icon: Iconsax.video,
                    title: 'Chọn video',
                    isLast: false,
                  ),
                  _StepTile(
                    stepNumber: '2',
                    icon: Iconsax.cloud_add,
                    title: 'Tải lên hệ thống',
                    isLast: false,
                  ),
                  _StepTile(
                    stepNumber: '3',
                    icon: Iconsax.cpu,
                    title: 'AI phân tích trong nền',
                    isLast: false,
                  ),
                  _StepTile(
                    stepNumber: '4',
                    icon: Iconsax.notification,
                    title: 'Nhận cảnh báo nếu có sự cố',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton.icon(
                onPressed: onChooseVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Iconsax.video_add, size: 22),
                label: const Text(
                  'Chọn video từ thư viện',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Bạn sẽ nhận thông báo khi AI phát hiện cảnh báo.\nVideo chỉ dùng cho luồng demo phân tích sự kiện.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? theme.colorScheme.onSurfaceVariant
                      : AppColors.mutedText,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.stepNumber,
    required this.icon,
    required this.title,
    required this.isLast,
  });

  final String stepNumber;
  final IconData icon;
  final String title;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest
                        : AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    stepNumber,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.colorScheme.surfaceContainerHighest
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                if (isLast) const SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isDark
                          ? theme.colorScheme.onSurfaceVariant
                          : AppColors.mutedText,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? theme.colorScheme.onSurface
                              : AppColors.darkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
