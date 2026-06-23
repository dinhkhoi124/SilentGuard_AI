import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/theme/theme_controller.dart';
import 'package:mobile/injection_container.dart';

class AppAppearancePage extends StatelessWidget {
  const AppAppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = sl<ThemeController>();

    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: SafeArea(
            child: Column(
              children: [
                _AppearanceHeader(onBack: () => context.pop()),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _SettingRow(
                        label: 'Chủ đề',
                        value: _themeModeLabel(themeController.themeMode),
                        onTap: () => _showThemeSheet(context, themeController),
                      ),
                      _SettingRow(
                        label: 'Ngôn ngữ ứng dụng',
                        value: 'Tiếng Việt',
                        onTap: () => _showLanguageSheet(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'Sáng',
      ThemeMode.dark => 'Tối',
      ThemeMode.system => 'Theo hệ thống',
    };
  }

  Future<void> _showThemeSheet(
    BuildContext context,
    ThemeController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return _OptionSheet(
              title: 'Chọn chủ đề',
              children: [
                _SheetOption(
                  label: 'Sáng',
                  selected: controller.themeMode == ThemeMode.light,
                  onTap: () {
                    controller.setThemeMode(ThemeMode.light);
                    context.pop();
                  },
                ),
                _SheetOption(
                  label: 'Tối',
                  selected: controller.themeMode == ThemeMode.dark,
                  onTap: () {
                    controller.setThemeMode(ThemeMode.dark);
                    context.pop();
                  },
                ),
                _SheetOption(
                  label: 'Theo hệ thống',
                  selected: controller.themeMode == ThemeMode.system,
                  onTap: () {
                    controller.setThemeMode(ThemeMode.system);
                    context.pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showLanguageSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return _OptionSheet(
          title: 'Ngôn ngữ ứng dụng',
          children: [
            _SheetOption(
              label: 'Tiếng Việt',
              selected: true,
              onTap: () => context.pop(),
            ),
          ],
        );
      },
    );
  }
}

class _AppearanceHeader extends StatelessWidget {
  const _AppearanceHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: colorScheme.onSurface,
                tooltip: 'Quay lại',
              ),
            ),
          ),
          Text(
            'Giao diện ứng dụng',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionSheet extends StatelessWidget {
  const _OptionSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      // borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: colorScheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
