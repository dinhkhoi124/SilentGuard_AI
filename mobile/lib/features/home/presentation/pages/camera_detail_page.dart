// lib/features/home/presentation/pages/camera_detail_page.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/domain/entities/camera_event.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mobile/features/home/presentation/bloc/home_state.dart';
import 'package:mobile/features/home/presentation/cubit/camera_event_history_cubit.dart';
import 'package:mobile/features/home/presentation/cubit/camera_event_history_state.dart';
import 'package:mobile/features/home/presentation/mappers/camera_event_adapter.dart';
import 'package:mobile/features/home/presentation/widgets/camera_action_buttons.dart';
import 'package:mobile/features/home/presentation/widgets/camera_event_history_header.dart';
import 'package:mobile/features/home/presentation/widgets/camera_event_tile.dart';
import 'package:mobile/features/home/presentation/widgets/camera_latest_event_card.dart';
import 'package:mobile/features/home/presentation/widgets/camera_safety_status.dart';
import 'package:mobile/features/home/presentation/widgets/camera_top_bar.dart';
import 'package:mobile/features/home/presentation/widgets/camera_video_player.dart';
import 'package:mobile/injection_container.dart';

class CameraDetailArgs {
  const CameraDetailArgs({required this.device, this.onThumbnailCaptured});

  final CameraDevice device;
  final ValueChanged<Uint8List>? onThumbnailCaptured;
}

class CameraDetailPage extends StatelessWidget {
  const CameraDetailPage({
    super.key,
    required this.device,
    this.onThumbnailCaptured,
  });

  final CameraDevice device;
  final ValueChanged<Uint8List>? onThumbnailCaptured;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CameraEventHistoryCubit>(
      create: (_) => sl<CameraEventHistoryCubit>()..loadForCamera(device),
      child: _CameraDetailBody(
        device: device,
        onThumbnailCaptured: onThumbnailCaptured,
      ),
    );
  }
}

class _CameraDetailBody extends StatefulWidget {
  const _CameraDetailBody({required this.device, this.onThumbnailCaptured});

  final CameraDevice device;
  final ValueChanged<Uint8List>? onThumbnailCaptured;

  @override
  State<_CameraDetailBody> createState() => _CameraDetailBodyState();
}

class _CameraDetailBodyState extends State<_CameraDetailBody> {
  Timer? _clockTimer;
  String _currentTime = '';
  late String? _streamUrl;
  late bool _isStreamLoading;
  bool _showLoadingForNextStreamRequest = false;
  String? _streamErrorMessage;

  @override
  void initState() {
    super.initState();
    _streamUrl = _normalizedUrl(widget.device.rtspUrl);
    _isStreamLoading = _streamUrl == null;
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTime();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestStreamUrl(showLoading: _streamUrl == null);
    });
  }

  void _updateTime() {
    if (!mounted) return;
    setState(() => _currentTime = _formatTime(DateTime.now()));
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeBloc, HomeState>(
      listenWhen: (_, state) =>
          state is CameraStreamUrlLoading ||
          state is CameraStreamUrlLoaded ||
          state is CameraStreamUrlFailure,
      listener: (context, state) {
        if (state is CameraStreamUrlLoading &&
            state.cameraId == widget.device.id) {
          setState(() {
            _isStreamLoading =
                _streamUrl == null || _showLoadingForNextStreamRequest;
            _streamErrorMessage = null;
          });
          return;
        }
        if (state is CameraStreamUrlLoaded &&
            state.cameraId == widget.device.id) {
          setState(() {
            _streamUrl = state.streamUrl;
            _isStreamLoading = false;
            _showLoadingForNextStreamRequest = false;
            _streamErrorMessage = null;
          });
          return;
        }
        if (state is CameraStreamUrlFailure &&
            state.cameraId == widget.device.id) {
          setState(() {
            _isStreamLoading = false;
            _showLoadingForNextStreamRequest = false;
            _streamErrorMessage = state.message;
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: CameraTopBar(
                  device: widget.device,
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                  onSettings: _showCameraOptions,
                ),
              ),
              SliverToBoxAdapter(
                child: BlocBuilder<HomeBloc, HomeState>(
                  buildWhen: (_, state) =>
                      state is CameraStreamUrlLoading ||
                      state is CameraStreamUrlLoaded ||
                      state is CameraStreamUrlFailure,
                  builder: (context, state) {
                    return CameraVideoPlayer(
                      rtspUrl: _streamUrl,
                      currentTime: _currentTime,
                      onFrameCaptured: widget.onThumbnailCaptured,
                      isLoading: _isStreamLoading,
                      errorMessage: _streamErrorMessage,
                      onRetry: () => _requestStreamUrl(showLoading: true),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: CameraSafetyStatus(
                  device: widget.device,
                  updateTime: TimeOfDay.now().format(context),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              // Latest event card / no-events panel — driven by history state
              SliverToBoxAdapter(
                child:
                    BlocBuilder<
                      CameraEventHistoryCubit,
                      CameraEventHistoryState
                    >(
                      builder: (context, state) {
                        final latestEvent = switch (state) {
                          CameraEventHistoryLoaded(:final items)
                              when items.isNotEmpty =>
                            CameraEventAdapter.fromEventHistoryItem(
                              items.first,
                            ),
                          _ => null,
                        };
                        if (latestEvent != null) {
                          return CameraLatestEventCard(
                            device: widget.device,
                            latestEvent: latestEvent,
                          );
                        }
                        return const _NoCameraEventsPanel();
                      },
                    ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              const SliverToBoxAdapter(child: CameraActionButtons()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              const SliverToBoxAdapter(child: CameraEventHistoryHeader()),
              // Event history list — driven by CameraEventHistoryCubit
              BlocBuilder<CameraEventHistoryCubit, CameraEventHistoryState>(
                builder: (context, state) {
                  return switch (state) {
                    CameraEventHistoryInitial() ||
                    CameraEventHistoryLoading() => _SliverEventSection(
                      child: _HistoryLoadingBody(),
                    ),
                    CameraEventHistoryLoaded(:final items) => _SliverEventList(
                      events: CameraEventAdapter.fromList(items),
                    ),
                    CameraEventHistoryEmpty() => _SliverEventSection(
                      child: _HistoryEmptyBody(message: 'Chưa có sự kiện nào.'),
                    ),

                    CameraEventHistoryError() => _SliverEventSection(
                      child: _HistoryErrorBody(
                        onRetry: () => context
                            .read<CameraEventHistoryCubit>()
                            .retry(widget.device),
                      ),
                    ),
                  };
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  void _requestStreamUrl({required bool showLoading}) {
    final serialNumber = widget.device.serialNumber?.trim() ?? '';
    if (serialNumber.isEmpty) {
      setState(() {
        _streamUrl = null;
        _showLoadingForNextStreamRequest = false;
        _isStreamLoading = false;
        _streamErrorMessage =
            'Không tìm thấy mã serial của camera. Vui lòng ghép nối lại thiết bị.';
      });
      return;
    }

    setState(() {
      _showLoadingForNextStreamRequest = showLoading;
      _isStreamLoading = showLoading || _streamUrl == null;
      _streamErrorMessage = null;
    });
    context.read<HomeBloc>().add(
      CameraStreamUrlRequested(
        cameraId: widget.device.id,
        serialNumber: serialNumber,
      ),
    );
  }

  Future<void> _showCameraOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 18),
              Text(
                'Tùy chọn camera',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.device.location,
                style: Theme.of(
                  sheetContext,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
              ),
              const SizedBox(height: 18),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final scheduled = await sl<LocalNotificationService>()
                      .scheduleFallAlert(widget.device);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        scheduled
                            ? 'Thông báo giả lập sẽ xuất hiện sau 5 giây.'
                            : 'Cần cấp quyền thông báo để giả lập cảnh báo.',
                      ),
                    ),
                  );
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                          child: SizedBox.square(
                            dimension: 42,
                            child: Icon(
                              Icons.notifications_active_outlined,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Giả lập cảnh báo té ngã',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: AppColors.darkText,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Gửi thông báo sau 5 giây.',
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.mutedText),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.mutedText,
                        ),
                      ],
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
}

// ─── helper sliver wrappers ───────────────────────────────────────────────────

class _SliverEventSection extends StatelessWidget {
  const _SliverEventSection({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: child);
  }
}

class _SliverEventList extends StatelessWidget {
  const _SliverEventList({required this.events});
  final List<CameraEvent> events;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, index) => CameraEventTile(event: events[index]),
        childCount: events.length,
      ),
    );
  }
}

// ─── section-level state bodies (small, focused) ─────────────────────────────

class _HistoryLoadingBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Đang tải lịch sử sự kiện...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmptyBody extends StatelessWidget {
  const _HistoryEmptyBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
      ),
    );
  }
}

class _HistoryErrorBody extends StatelessWidget {
  const _HistoryErrorBody({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Không thể tải lịch sử sự kiện. Vui lòng thử lại.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

// ─── existing private widgets (unchanged) ────────────────────────────────────

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

class _NoCameraEventsPanel extends StatelessWidget {
  const _NoCameraEventsPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: SizedBox.square(
                  dimension: 42,
                  child: Icon(
                    Icons.event_available_outlined,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chưa có sự kiện',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.darkText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sự kiện mới từ camera sẽ xuất hiện tại đây.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';
}

String? _normalizedUrl(String? url) {
  final trimmed = url?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
