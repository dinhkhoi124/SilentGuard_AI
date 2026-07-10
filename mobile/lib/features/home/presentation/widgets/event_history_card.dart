import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/reports/domain/entities/event_history_item.dart';
import 'package:mobile/features/home/domain/entities/event_feedback_label.dart';
import 'package:mobile/features/home/presentation/cubit/event_feedback_cubit.dart';
import 'package:mobile/features/home/presentation/cubit/event_feedback_state.dart';

class EventHistoryCard extends StatelessWidget {
  const EventHistoryCard({
    super.key,
    required this.item,
    this.onAcknowledge,
    this.isSubmitting = false,
    this.onFeedback,
  });

  final EventHistoryItem item;
  final VoidCallback? onAcknowledge;
  final bool isSubmitting;
  final VoidCallback? onFeedback;

  @override
  Widget build(BuildContext context) {
    final canFeedback =
        item.status == EventStatus.pending ||
        item.status == EventStatus.escalated ||
        item.status == EventStatus.loggedOnly ||
        item.status == EventStatus.recovered;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _iconForSeverity(item.severity),
                      color: _colorForSeverity(item.severity),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _titleForSeverity(item.severity),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (_shouldShowBadge(item.severity)) ...[
                      const SizedBox(width: 8),
                      _SeverityBadge(severity: item.severity),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    _buildMetadata(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedText,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusChip(status: item.status),
                if (canFeedback && onFeedback != null)
                  _FeedbackButton(
                    onFeedback: onFeedback,
                    isSubmitting: isSubmitting,
                  )
                else if (onAcknowledge != null &&
                    item.status == EventStatus.pending)
                  _AcknowledgeButton(
                    onAcknowledge: onAcknowledge,
                    isSubmitting: isSubmitting,
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleForSeverity(EventSeverity severity) {
    return switch (severity) {
      EventSeverity.low => 'Sự kiện nhẹ',
      EventSeverity.medium => 'Cảnh báo cần kiểm tra',
      EventSeverity.high => 'Cảnh báo té ngã',
      EventSeverity.critical => 'Nguy hiểm khẩn cấp',
      EventSeverity.system => 'Sự kiện hệ thống',
      EventSeverity.unknown => 'Sự kiện camera',
    };
  }

  IconData _iconForSeverity(EventSeverity severity) {
    return switch (severity) {
      EventSeverity.critical => Icons.warning_amber_rounded,
      EventSeverity.high => Icons.accessibility_new,
      EventSeverity.medium => Icons.airline_seat_flat,
      EventSeverity.low => Icons.directions_run,
      _ => Icons.info_outline,
    };
  }

  Color _colorForSeverity(EventSeverity severity) {
    return switch (severity) {
      EventSeverity.critical => AppColors.destructive,
      EventSeverity.high => const Color(0xFFE53935),
      EventSeverity.medium => AppColors.warning,
      EventSeverity.low => AppColors.safe,
      _ => AppColors.mutedText,
    };
  }

  bool _shouldShowBadge(EventSeverity severity) {
    return severity == EventSeverity.medium ||
        severity == EventSeverity.high ||
        severity == EventSeverity.critical;
  }

  String _buildMetadata() {
    final parts = <String>[];
    if (item.timestamp != null) {
      final h = item.timestamp!.hour.toString().padLeft(2, '0');
      final m = item.timestamp!.minute.toString().padLeft(2, '0');
      parts.add('$h:$m');
    }
    parts.add(item.room);
    if (item.durationSec != null && item.durationSec! > 0) {
      parts.add('${item.durationSec}s');
    }
    if (item.confidence != null) {
      parts.add('${(item.confidence! * 100).toStringAsFixed(0)}% tin cậy');
    }
    return parts.join(' · ');
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case EventStatus.pending:
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
        label = 'Đang chờ';
        break;
      case EventStatus.acknowledged:
        bgColor = AppColors.safe;
        textColor = Colors.white;
        label = 'Đã xử lý';
        break;
      case EventStatus.dismissed:
        bgColor = AppColors.mutedText;
        textColor = Colors.white;
        label = 'Báo động giả';
        break;
      case EventStatus.escalated:
        bgColor = Colors.deepOrange;
        textColor = Colors.white;
        label = 'Đã chuyển tiếp';
        break;
      case EventStatus.loggedOnly:
        bgColor = Colors.blueGrey.shade100;
        textColor = Colors.blueGrey.shade900;
        label = 'Chỉ ghi nhận';
        break;
      case EventStatus.recovered:
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        label = 'Đã hồi phục';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({this.onFeedback, required this.isSubmitting});
  final VoidCallback? onFeedback;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    if (isSubmitting) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return OutlinedButton(
      onPressed: onFeedback,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1),
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
      child: const Text(
        'Phản hồi',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AcknowledgeButton extends StatelessWidget {
  const _AcknowledgeButton({this.onAcknowledge, required this.isSubmitting});
  final VoidCallback? onAcknowledge;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    if (isSubmitting) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return OutlinedButton(
      onPressed: onAcknowledge,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.primary.withValues(alpha: 0.05),
        side: const BorderSide(color: Colors.transparent),
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
      child: const Text(
        'Xác nhận',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final EventSeverity severity;

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      EventSeverity.critical => AppColors.destructive,
      EventSeverity.high => const Color(0xFFE53935),
      EventSeverity.medium => AppColors.warning,
      _ => AppColors.mutedText,
    };

    final label = switch (severity) {
      EventSeverity.critical => 'NGUY HIỂM',
      EventSeverity.high => 'MỨC CAO',
      EventSeverity.medium => 'TRUNG BÌNH',
      _ => '',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── BOTTOM SHEET (COPIED FROM CAMERA_EVENT_TILE TO AVOID BREAKING IT) ──────────

class _ReviewBottomSheet extends StatefulWidget {
  const _ReviewBottomSheet();

  @override
  State<_ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<_ReviewBottomSheet> {
  final TextEditingController _falsePositiveReasonController =
      TextEditingController();

  @override
  void dispose() {
    _falsePositiveReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const SizedBox(width: 40, height: 5),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Kết quả thực tế?',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              _ReviewChoiceTile(
                title: 'Có người bị ngã',
                subtitle: 'Xác nhận đây là cảnh báo đúng.',
                icon: Icons.accessibility_new,
                onTap: () =>
                    _submit(const _ReviewChoice(action: 'acknowledged')),
              ),
              const SizedBox(height: 10),
              _ReviewChoiceTile(
                title: 'Không có người bị ngã',
                subtitle: 'Đánh dấu cảnh báo nhầm.',
                icon: Icons.close_rounded,
                onTap: () => _submit(
                  _ReviewChoice(
                    action: 'dismissed',
                    note: _falsePositiveReasonController.text.trim(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _falsePositiveReasonController,
                    decoration: InputDecoration(
                      labelText: 'Lý do (tùy chọn)',
                      labelStyle: const TextStyle(color: AppColors.mutedText),
                      filled: true,
                      fillColor: AppColors.surfaceSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(_ReviewChoice choice) {
    Navigator.of(context).pop(choice);
  }
}

class _ReviewChoice {
  const _ReviewChoice({required this.action, this.note});

  final String action;
  final String? note;
}

class _ReviewChoiceTile extends StatelessWidget {
  const _ReviewChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.isLoading = false,
    this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SizedBox.square(
                      dimension: 42,
                      child: isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(icon, color: AppColors.primary, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.darkText,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ?child,
            ],
          ),
        ),
      ),
    );
  }
}

class EventFeedbackBottomSheet extends StatelessWidget {
  const EventFeedbackBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EventFeedbackCubit, EventFeedbackState>(
      listener: (context, state) {
        if (state is EventFeedbackSuccess) {
          Navigator.of(context).pop();

          final snackBarContent = state.warning != null
              ? 'Đã ghi nhận phản hồi. ${state.warning}'
              : 'Đã ghi nhận phản hồi';

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(snackBarContent)));
        }
      },
      builder: (context, state) {
        final isSubmitting = state is EventFeedbackSubmitting;
        final submittingLabel = isSubmitting ? state.label : null;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                10,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const SizedBox(width: 40, height: 5),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Xác nhận kết quả',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (state is EventFeedbackFailure) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lỗi: ${state.message}. Vui lòng thử lại.',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _ReviewChoiceTile(
                      title: 'Đúng cảnh báo',
                      subtitle: 'Sự kiện này được AI nhận diện đúng.',
                      icon: Icons.check_circle_outline,
                      isLoading: submittingLabel == EventFeedbackLabel.correct,
                      onTap: isSubmitting
                          ? null
                          : () => context.read<EventFeedbackCubit>().submit(
                              label: EventFeedbackLabel.correct,
                            ),
                    ),
                    const SizedBox(height: 10),
                    _ReviewChoiceTile(
                      title: 'Cảnh báo nhầm',
                      subtitle: 'Hệ thống đã nhận diện nhầm.',
                      icon: Icons.cancel_outlined,
                      isLoading:
                          submittingLabel == EventFeedbackLabel.incorrect,
                      onTap: isSubmitting
                          ? null
                          : () => context.read<EventFeedbackCubit>().submit(
                              label: EventFeedbackLabel.incorrect,
                            ),
                    ),
                    const SizedBox(height: 10),
                    _ReviewChoiceTile(
                      title: 'Không rõ',
                      subtitle: 'Không thể xác định từ camera.',
                      icon: Icons.help_outline,
                      isLoading:
                          submittingLabel == EventFeedbackLabel.uncertain,
                      onTap: isSubmitting
                          ? null
                          : () => context.read<EventFeedbackCubit>().submit(
                              label: EventFeedbackLabel.uncertain,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
