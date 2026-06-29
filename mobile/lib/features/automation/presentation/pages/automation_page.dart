import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/features/automation/presentation/widgets/ai_config_card.dart';
import 'package:mobile/features/automation/presentation/widgets/automation_header.dart';
import 'package:mobile/features/automation/presentation/widgets/automation_rules_section.dart';
import 'package:mobile/features/automation/presentation/widgets/automation_section_header.dart';
import 'package:mobile/features/automation/presentation/widgets/automation_status_card.dart';
import 'package:mobile/features/automation/presentation/widgets/emergency_contacts_preview.dart';
import 'package:mobile/features/automation/presentation/widgets/quiet_window_card.dart';
import 'package:mobile/features/automation/presentation/widgets/severity_timeline.dart';

class AutomationPage extends StatelessWidget {
  const AutomationPage({super.key});

  void _showComingSoonSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              24,
              AppSpacing.pagePadding,
              20,
            ),
            sliver: SliverList.list(
              children: [
                const AutomationHeader(),
                const SizedBox(height: 24),
                const AutomationStatusCard(),
                const SizedBox(height: 32),
                const AutomationSectionHeader(title: 'Quy tắc cảnh báo'),
                const SizedBox(height: 12),
                const AutomationRulesSection(),
                const SizedBox(height: 32),
                const AutomationSectionHeader(
                  title: 'Luồng phản ứng theo mức độ',
                ),
                const SizedBox(height: 16),
                const SeverityTimeline(),
                const SizedBox(height: 32),
                const AutomationSectionHeader(title: 'Liên hệ khẩn cấp'),
                const SizedBox(height: 12),
                EmergencyContactsPreview(
                  onManageContacts: () => _showComingSoonSnackBar(
                    context,
                    'Tính năng quản lý liên hệ sẽ được kết nối sau.',
                  ),
                ),
                const SizedBox(height: 32),
                const AutomationSectionHeader(
                  title: 'Khung giờ giảm làm phiền',
                ),
                const SizedBox(height: 12),
                QuietWindowCard(
                  onAddQuietWindow: () => _showComingSoonSnackBar(
                    context,
                    'Tính năng này sẽ được kết nối sau.',
                  ),
                ),
                const SizedBox(height: 32),
                const AutomationSectionHeader(title: 'Cấu hình bằng AI'),
                const SizedBox(height: 12),
                AiConfigCard(
                  onTryAiConfig: () => _showComingSoonSnackBar(
                    context,
                    'Trợ lý AI cấu hình sẽ được kết nối sau.',
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
