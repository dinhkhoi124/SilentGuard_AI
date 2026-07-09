import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/account/presentation/widgets/account_page_header.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // Mock local state
  final Map<String, bool> _preferences = {
    'Cảnh báo té ngã': true,
    'Cảnh báo camera mất kết nối': true,
    'Lời mời gia đình': true,
    'Báo cáo hằng ngày': true,
    'Nhắc kiểm tra người thân': false,
    'Cập nhật tự động hóa': false,
    'Bảo trì thiết bị': false,
    'Cảnh báo bảo mật tài khoản': true,
    'Gợi ý theo thời tiết': false,
    'Cập nhật hệ thống': false,
    'Hỗ trợ khách hàng': false,
    'Phản hồi & cải tiến': false,
  };

  final List<String> _keys = [
    'Cảnh báo té ngã',
    'Cảnh báo camera mất kết nối',
    'Lời mời gia đình',
    'Báo cáo hằng ngày',
    'Nhắc kiểm tra người thân',
    'Cập nhật tự động hóa',
    'Bảo trì thiết bị',
    'Cảnh báo bảo mật tài khoản',
    'Gợi ý theo thời tiết',
    'Cập nhật hệ thống',
    'Hỗ trợ khách hàng',
    'Phản hồi & cải tiến',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const AccountPageHeader(title: 'Cài đặt thông báo'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: AppSpacing.xxxl),
                itemCount: _keys.length,
                itemBuilder: (context, index) {
                  final key = _keys[index];
                  final value = _preferences[key] ?? false;
                  return _NotificationPreferenceTile(
                    title: key,
                    value: value,
                    onChanged: (newValue) {
                      setState(() {
                        _preferences[key] = newValue;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationPreferenceTile extends StatelessWidget {
  const _NotificationPreferenceTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : AppColors.darkText;

    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            CupertinoSwitch(
              value: value,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.border,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
