// lib/features/home/presentation/widgets/camera_event_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/domain/entities/alert_review_feedback.dart';
import 'package:mobile/features/home/domain/entities/camera_event.dart';
import 'package:mobile/features/home/presentation/cubit/alert_review_cubit.dart';
import 'package:mobile/features/home/presentation/cubit/camera_event_history_cubit.dart';
import 'package:mobile/features/reports/domain/entities/event_history_item.dart';
import 'package:mobile/injection_container.dart';

class CameraEventTile extends StatelessWidget {
  const CameraEventTile({
    super.key,
    required this.event,
  });

  final CameraEvent event;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AlertReviewCubit>(),
      child: _CameraEventTileContent(event: event),
    );
  }
}

class _CameraEventTileContent extends StatelessWidget {
  const _CameraEventTileContent({required this.event});

  final CameraEvent event;

  @override
  Widget build(BuildContext context) {
    final appearance = _eventAppearance(event.type);
    final levelAppearance = _eventLevelAppearance(event.level);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CircleIcon(
                icon: appearance.icon,
                backgroundColor: appearance.backgroundColor,
                iconColor: appearance.iconColor,
                size: 42,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkText,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (levelAppearance.badge != null) ...[
                          const SizedBox(width: 8),
                          levelAppearance.badge!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _buildMetadata(event),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BlocConsumer<AlertReviewCubit, AlertReviewState>(
            listenWhen: (_, state) => state is ReviewSuccess,
            listener: (context, state) {
              if (state is ReviewSuccess) {
                final newStatus = state.feedback.action == 'acknowledged'
                    ? EventStatus.acknowledged
                    : EventStatus.dismissed;
                context.read<CameraEventHistoryCubit>().updateEventStatus(event.id, newStatus);
              }
            },
            builder: (context, state) {
              return _FeedbackStatusRow(event: event, state: state);
            },
          ),
        ],
      ),
    );
  }

  String _buildMetadata(CameraEvent event) {
    final parts = <String>[
      event.time,
      event.room,
      if (event.durationSec != null && event.durationSec! > 0)
        '${event.durationSec}s',
      if (event.confidence != null)
        '${(event.confidence! * 100).toStringAsFixed(0)}% tin cậy',
    ];
    return parts.join(' · ');
  }
}

class _FeedbackStatusRow extends StatelessWidget {
  const _FeedbackStatusRow({required this.event, required this.state});

  final CameraEvent event;
  final AlertReviewState state;

  @override
  Widget build(BuildContext context) {
    final appearance = _feedbackAppearance(state);

    final String displayLabel = state is ReviewInitial
        ? event.statusLabel
        : appearance.label;

    final Color displayColor = state is ReviewInitial
        ? _statusColor(event.statusLabel)
        : appearance.color;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FeedbackChip(label: displayLabel, color: displayColor),
        if (state is ReviewInitial && event.statusLabel == 'Đang chờ')
          _FeedbackActionButton(
            label: 'Xác nhận kết quả',
            onPressed: () => _openReviewSheet(context),
          ),
        if (state is ReviewFailure)
          _FeedbackActionButton(
            label: 'Thử lại',
            onPressed: () {
              context.read<AlertReviewCubit>().retry();
            },
          ),
      ],
    );
  }

  Future<void> _openReviewSheet(BuildContext context) async {
    final cubit = context.read<AlertReviewCubit>();
    final result = await showModalBottomSheet<_ReviewChoice>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (sheetContext) => const _ReviewBottomSheet(),
    );

    if (result == null) return;
    await cubit.submit(
      AlertReviewFeedback(
        eventId: event.id,
        action: result.action,
        note: result.note,
      ),
    );
  }

  Color _statusColor(String statusLabel) {
    if (statusLabel == 'Đang chờ') return const Color(0xFFD97706); // Amber 600 for premium yellow
    if (statusLabel == 'Đã xử lý') return const Color(0xFF2E7D32);
    if (statusLabel == 'Báo động giả') return AppColors.mutedText;
    if (statusLabel == 'Đã chuyển tiếp') return const Color(0xFFE53935);
    return AppColors.mutedText;
  }
}

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
              const _SheetHandle(),
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
                onTap: () => _submit(
                  const _ReviewChoice(action: 'acknowledged'),
                ),
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
    required this.onTap,
    this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSoft,
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
                      child: Icon(icon, color: AppColors.primary, size: 22),
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

class _FeedbackActionButton extends StatelessWidget {
  const _FeedbackActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size.zero,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(99),
        ),
        child: const SizedBox(width: 40, height: 5),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.size,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: size / 2),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
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

({String label, Color color}) _feedbackAppearance(AlertReviewState state) {
  return switch (state) {
    ReviewInitial() => (
      label: 'Chưa xác nhận',
      color: AppColors.mutedText,
    ),
    ReviewSubmitting() => (
      label: 'Đang gửi phản hồi...',
      color: AppColors.mutedText,
    ),
    ReviewSuccess(:final feedback) => switch (feedback.action) {
      'acknowledged' => (
        label: 'Đã xác nhận: Té ngã thật',
        color: const Color(0xFF2E7D32),
      ),
      'dismissed' => (
        label: 'Đã xác nhận: Báo động giả',
        color: AppColors.primary,
      ),
      _ => (
        label: 'Đã xác nhận',
        color: AppColors.mutedText,
      ),
    },
    ReviewFailure() => (
      label: 'Chưa đồng bộ',
      color: const Color(0xFFF57C00),
    ),
  };
}

({Color backgroundColor, Color iconColor, IconData icon}) _eventAppearance(
  EventType type,
) {
  return switch (type) {
    EventType.fall => (
      backgroundColor: const Color(0xFFFFE5E5),
      iconColor: const Color(0xFFE53935),
      icon: Icons.accessibility_new,
    ),
    EventType.still => (
      backgroundColor: const Color(0xFFFFF3E0),
      iconColor: const Color(0xFFFF9800),
      icon: Icons.airline_seat_flat,
    ),
    EventType.normal => (
      backgroundColor: const Color(0xFFE8F5E9),
      iconColor: AppColors.safe,
      icon: Icons.directions_run,
    ),
    EventType.reconnect => (
      backgroundColor: const Color(0xFFF5F5F5),
      iconColor: AppColors.mutedText,
      icon: Icons.videocam_off_outlined,
    ),
  };
}

({Color timeColor, _LevelBadge? badge}) _eventLevelAppearance(
  EventLevel level,
) {
  return switch (level) {
    EventLevel.high => (
      timeColor: const Color(0xFFE53935),
      badge: const _LevelBadge(label: 'Mức cao', color: Color(0xFFE53935)),
    ),
    EventLevel.medium => (
      timeColor: const Color(0xFFFF9800),
      badge: const _LevelBadge(
        label: 'Mức trung bình',
        color: Color(0xFFFF9800),
      ),
    ),
    _ => (timeColor: AppColors.darkText, badge: null),
  };
}
