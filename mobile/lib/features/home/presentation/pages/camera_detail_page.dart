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
import 'package:mobile/features/home/presentation/cubit/suppress_cubit.dart';
import 'package:mobile/features/home/presentation/mappers/camera_event_adapter.dart';
import 'package:mobile/features/home/presentation/widgets/camera_action_buttons.dart';
import 'package:mobile/features/home/presentation/widgets/camera_event_history_header.dart';
import 'package:mobile/features/home/presentation/widgets/camera_event_tile.dart';
import 'package:mobile/features/home/presentation/widgets/camera_latest_event_card.dart';
import 'package:mobile/features/home/presentation/widgets/camera_safety_status.dart';
import 'package:mobile/core/widgets/app_empty_state.dart';
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
    return MultiBlocProvider(
      providers: [
        BlocProvider<CameraEventHistoryCubit>(
          create: (_) => sl<CameraEventHistoryCubit>()..loadForCamera(device),
        ),
        BlocProvider<SuppressCubit>(create: (_) => sl<SuppressCubit>()),
      ],
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
  late final CameraVideoPlayerController _videoPlayerController;
  Widget? _videoPlayerWidget;
  bool _isStreamRequestInFlight = false;
  bool _showLoadingForNextStreamRequest = false;
  String? _streamErrorMessage;

  @override
  void initState() {
    super.initState();
    context.read<SuppressCubit>().loadState(widget.device.id);
    context.read<HomeBloc>().add(const ResetCameraStreamUrlEvent());
    final cachedStreamUrl = _normalizedUrl(
      context.read<HomeBloc>().lastKnownStreamUrl,
    );
    _streamUrl = cachedStreamUrl ?? _normalizedUrl(widget.device.rtspUrl);
    debugPrint('[CameraDetail] initState streamUrl: $_streamUrl');
    _isStreamLoading = _streamUrl == null;
    debugPrint('[CameraDetail] initState isLoading: $_isStreamLoading');
    _videoPlayerController = CameraVideoPlayerController(
      currentTime: _currentTime,
      isLoading: _isStreamLoading,
      errorMessage: _streamErrorMessage,
    );
    _videoPlayerWidget = _streamUrl == null
        ? null
        : _createVideoPlayer(_streamUrl!);
    debugPrint(
      '[CameraDetail] VideoPlayer widget created, url: '
      '${_redactedNullableStreamUrl(_streamUrl)}',
    );
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTime();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (cachedStreamUrl != null) {
        return;
      }
      _requestStreamUrl(showLoading: _streamUrl == null);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint(
      '[CameraDetail] didChangeDependencies() at: ${DateTime.now().toIso8601String()}',
    );
  }

  void _updateTime() {
    if (!mounted) return;
    final nextTime = _formatTime(DateTime.now());
    _videoPlayerController.update(currentTime: nextTime);
    _currentTime = nextTime;
  }

  @override
  void dispose() {
    debugPrint(
      '[CameraDetail] dispose() called at: ${DateTime.now().toIso8601String()}',
    );
    final serialNumber = widget.device.serialNumber?.trim();
    if (serialNumber != null && serialNumber.isNotEmpty) {
      context.read<HomeBloc>().add(
        CameraDetailClosed(serialNumber: serialNumber),
      );
    }
    _clockTimer?.cancel();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[CameraDetail] build() called, streamUrl: '
      '${_redactedNullableStreamUrl(_streamUrl)}, isLoading: $_isStreamLoading',
    );
    return MultiBlocListener(
      listeners: [
        BlocListener<HomeBloc, HomeState>(
          listenWhen: (_, state) =>
              state is CameraStreamUrlLoading ||
              state is CameraStreamUrlLoaded ||
              state is CameraStreamUrlFailure ||
              state is CameraPlaybackFailure,
          listener: (context, state) {
            debugPrint(
              '[CameraDetail] BlocListener state: ${state.runtimeType}',
            );
            if (state is CameraStreamUrlLoading &&
                state.cameraId == widget.device.id) {
              setState(() {
                _isStreamLoading =
                    _streamUrl == null || _showLoadingForNextStreamRequest;
                _streamErrorMessage = null;
              });
              _videoPlayerController.update(
                isLoading: _isStreamLoading,
                clearError: true,
              );
              return;
            }
            if (state is CameraStreamUrlLoaded) {
              if (state.cameraId != widget.device.id) return;
              debugPrint(
                '[CameraDetail] URL received: ${_redactedStreamUrl(state.streamUrl)}',
              );
              debugPrint(
                '[CameraDetail] URL timestamp: ${DateTime.now().toIso8601String()}',
              );
              _isStreamRequestInFlight = false;
              setState(() {
                _streamUrl = state.streamUrl;
                _videoPlayerWidget = _createVideoPlayer(state.streamUrl);
                _isStreamLoading = false;
                _showLoadingForNextStreamRequest = false;
                _streamErrorMessage = null;
              });
              _videoPlayerController.update(isLoading: false, clearError: true);
              return;
            }
            if (state is CameraStreamUrlFailure) {
              if (state.cameraId != widget.device.id) return;
              debugPrint('[CameraDetail] Stream FAILED: ${state.message}');
              _isStreamRequestInFlight = false;
              setState(() {
                _isStreamLoading = false;
                _showLoadingForNextStreamRequest = false;
                _streamErrorMessage = state.message;
              });
              _videoPlayerController.update(
                isLoading: false,
                errorMessage: state.message,
              );
              return;
            }
            if (state is CameraPlaybackFailure) {
              if (state.cameraId != widget.device.id) return;
              debugPrint('[CameraDetail] Playback FAILED: ${state.error}');
              _isStreamRequestInFlight = false;
              setState(() {
                _isStreamLoading = false;
                _showLoadingForNextStreamRequest = false;
                _streamErrorMessage = state.message;
              });
              _videoPlayerController.update(
                isLoading: false,
                errorMessage: state.message,
              );
            }
          },
        ),
        BlocListener<SuppressCubit, SuppressState>(
          listenWhen: (_, state) => state is SuppressFailure,
          listener: (context, state) {
            final failure = state as SuppressFailure;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            SliverSafeArea(
              sliver: SliverToBoxAdapter(
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
            ),
            SliverToBoxAdapter(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: BlocBuilder<HomeBloc, HomeState>(
                  buildWhen: (_, state) =>
                      state is CameraStreamUrlLoading ||
                      state is CameraStreamUrlLoaded ||
                      state is CameraStreamUrlFailure ||
                      state is CameraPlaybackFailure,
                  builder: (context, state) => _buildVideoArea(),
                ),
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
                  BlocBuilder<CameraEventHistoryCubit, CameraEventHistoryState>(
                    builder: (context, state) {
                      final latestEvent = switch (state) {
                        CameraEventHistoryLoaded(:final items)
                            when items.isNotEmpty =>
                          CameraEventAdapter.fromEventHistoryItem(items.first),
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
            SliverToBoxAdapter(
              child: BlocBuilder<SuppressCubit, SuppressState>(
                builder: (context, state) => _buildActionButtons(state),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: CameraEventHistoryHeader()),
            // Event history list — driven by CameraEventHistoryCubit
            BlocBuilder<CameraEventHistoryCubit, CameraEventHistoryState>(
              builder: (context, state) {
                return switch (state) {
                  CameraEventHistoryInitial() || CameraEventHistoryLoading() =>
                    _SliverEventSection(child: _HistoryLoadingBody()),
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
    );
  }

  void _requestStreamUrl({required bool showLoading}) {
    final serialNumber = widget.device.serialNumber?.trim() ?? '';
    debugPrint(
      '[CameraDetail] _requestStreamUrl called, serial: $serialNumber, showLoading: $showLoading',
    );
    if (_isStreamRequestInFlight) {
      debugPrint('[CameraDetail] duplicate stream request ignored');
      return;
    }
    if (serialNumber.isEmpty) {
      setState(() {
        _streamUrl = null;
        _showLoadingForNextStreamRequest = false;
        _isStreamLoading = false;
        _streamErrorMessage =
            'Không tìm thấy mã serial của camera. Vui lòng ghép nối lại thiết bị.';
      });
      _videoPlayerController.update(
        isLoading: false,
        errorMessage: _streamErrorMessage,
      );
      return;
    }

    _isStreamRequestInFlight = true;
    setState(() {
      _showLoadingForNextStreamRequest = showLoading;
      _isStreamLoading = showLoading || _streamUrl == null;
      _streamErrorMessage = null;
    });
    _videoPlayerController.update(
      isLoading: _isStreamLoading,
      clearError: true,
    );
    context.read<HomeBloc>().add(
      CameraStreamUrlRequested(
        cameraId: widget.device.id,
        serialNumber: serialNumber,
      ),
    );
  }

  Widget _buildVideoArea() {
    final errorMessage = _streamErrorMessage;
    if (errorMessage != null && errorMessage.trim().isNotEmpty) {
      return _VideoErrorView(
        message: errorMessage,
        onRetry: () => _requestStreamUrl(showLoading: true),
      );
    }
    if (_isStreamLoading) {
      return const _VideoLoadingView();
    }
    final streamUrl = _streamUrl?.trim();
    if (streamUrl == null || streamUrl.isEmpty) {
      return _VideoErrorView(
        message: 'Chưa có đường dẫn livestream cho camera này.',
        onRetry: () => _requestStreamUrl(showLoading: true),
      );
    }
    return _videoPlayerWidget ?? _createVideoPlayer(streamUrl);
  }

  Widget _createVideoPlayer(String streamUrl) {
    return CameraVideoPlayer(
      key: ValueKey(streamUrl),
      rtspUrl: streamUrl,
      controller: _videoPlayerController,
      onFrameCaptured: widget.onThumbnailCaptured,
      onRetry: () => _requestStreamUrl(showLoading: true),
      onPlaybackError: (error) {
        if (!mounted) return;
        context.read<HomeBloc>().add(
          CameraStreamPlaybackFailed(cameraId: widget.device.id, error: error),
        );
      },
    );
  }

  Widget _buildActionButtons(SuppressState state) {
    return switch (state) {
      SuppressActive(:final suppressedUntil) => CameraActionButtons(
        monitoringIcon: Icons.play_circle_fill_rounded,
        monitoringLabel:
            'Tiếp tục\n${_formatRemainingDuration(suppressedUntil)}',
        monitoringActive: true,
        onMonitoringTap: () =>
            context.read<SuppressCubit>().resumeMonitoring(widget.device.id),
      ),
      SuppressLoading() || SuppressInitial() => const CameraActionButtons(
        monitoringIcon: Icons.pause_circle_outline_rounded,
        monitoringLabel: 'Đang xử lý',
        monitoringLoading: true,
      ),
      SuppressFailure() => CameraActionButtons(
        monitoringIcon: Icons.refresh_rounded,
        monitoringLabel: 'Thử lại\nthông báo',
        onMonitoringTap: () =>
            context.read<SuppressCubit>().loadState(widget.device.id),
      ),
      SuppressInactive() => CameraActionButtons(
        monitoringIcon: Icons.pause_circle_outline_rounded,
        monitoringLabel: 'Tạm dừng\ngiám sát',
        onMonitoringTap: _showSuppressDurationSheet,
      ),
    };
  }

  Future<void> _showSuppressDurationSheet() async {
    final suppressCubit = context.read<SuppressCubit>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: AppColors.darkText.withValues(alpha: 0.22),
      builder: (sheetContext) => BlocProvider(
        create: (_) => _PauseDurationCubit(),
        child: _PauseDurationSheet(
          onConfirm: (minutes) async {
            await suppressCubit.pauseMonitoring(widget.device.id, minutes);
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
        ),
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

class _VideoLoadingView extends StatelessWidget {
  const _VideoLoadingView();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
      ),
    );
  }
}

class _VideoErrorView extends StatelessWidget {
  const _VideoErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              size: 48,
              color: Colors.white54,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text(
                'Thử lại',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      child: AppEmptyState(
        icon: Icons.event_available_outlined,
        title: 'Chưa có sự kiện',
        message:
            'Camera này chưa ghi nhận cảnh báo nào. Đây là một tín hiệu tốt.',
        compact: true,
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: AppEmptyState(
        icon: Icons.event_available_outlined,
        title: 'Chưa có sự kiện',
        message: 'Sự kiện mới từ camera sẽ xuất hiện tại đây.',
        compact: true,
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
  if (url == null) return null;
  final trimmed = url.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _redactedStreamUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return 'invalid';
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port${uri.path}';
}

String _redactedNullableStreamUrl(String? url) {
  if (url == null || url.trim().isEmpty) return 'unavailable';
  return _redactedStreamUrl(url);
}

String _formatRemainingDuration(DateTime suppressedUntil) {
  final remaining = suppressedUntil.difference(DateTime.now().toUtc());
  final totalSeconds = remaining.inSeconds.clamp(0, 99 * 60 + 59);
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

class _PauseDurationState {
  const _PauseDurationState({
    this.selection = 15,
    this.customMinutes,
    this.errorMessage,
  });

  static const customSelection = -1;

  final int selection;
  final int? customMinutes;
  final String? errorMessage;

  int? get selectedMinutes {
    if (selection == customSelection) return customMinutes;
    return selection;
  }

  _PauseDurationState copyWith({
    int? selection,
    int? customMinutes,
    bool clearCustomMinutes = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return _PauseDurationState(
      selection: selection ?? this.selection,
      customMinutes: clearCustomMinutes
          ? null
          : customMinutes ?? this.customMinutes,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class _PauseDurationCubit extends Cubit<_PauseDurationState> {
  _PauseDurationCubit() : super(const _PauseDurationState());

  void selectPreset(int minutes) {
    emit(
      state.copyWith(
        selection: minutes,
        clearCustomMinutes: true,
        clearError: true,
      ),
    );
  }

  void selectCustom(int minutes) {
    emit(
      state.copyWith(
        selection: _PauseDurationState.customSelection,
        customMinutes: minutes,
        clearError: true,
      ),
    );
  }

  bool validate() {
    final minutes = state.selectedMinutes;
    if (minutes == null || minutes < 5) {
      emit(
        state.copyWith(
          errorMessage: 'Thời lượng tùy chỉnh tối thiểu là 5 phút.',
        ),
      );
      return false;
    }
    return true;
  }
}

class _PauseDurationSheet extends StatelessWidget {
  const _PauseDurationSheet({required this.onConfirm});

  final Future<void> Function(int minutes) onConfirm;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 22),
      child: SingleChildScrollView(
        child: BlocBuilder<_PauseDurationCubit, _PauseDurationState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PauseSheetIcon(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tạm dừng thông báo',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.darkText,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Chỉ áp dụng trên thiết bị này. Camera vẫn ghi hình và phát hiện sự kiện.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.mutedText,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: RadioGroup<int>(
                    groupValue: state.selection,
                    onChanged: (value) {
                      if (value == null) return;
                      if (value == _PauseDurationState.customSelection) {
                        _pickCustomDuration(context);
                        return;
                      }
                      context.read<_PauseDurationCubit>().selectPreset(value);
                    },
                    child: Column(
                      children: [
                        const _DurationOption(value: 15, label: '15 phút'),
                        const _DurationDivider(),
                        const _DurationOption(value: 30, label: '30 phút'),
                        const _DurationDivider(),
                        const _DurationOption(value: 60, label: '1 giờ'),
                        const _DurationDivider(),
                        _DurationOption(
                          value: _PauseDurationState.customSelection,
                          label: 'Tùy chỉnh',
                          detail: state.customMinutes == null
                              ? 'Chọn giờ và phút'
                              : _formatCustomMinutes(state.customMinutes!),
                          trailing: const Icon(
                            Icons.schedule_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: state.errorMessage == null
                      ? const SizedBox(height: 18)
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            state.errorMessage!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.destructive,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final cubit = context.read<_PauseDurationCubit>();
                      if (!cubit.validate()) return;
                      await onConfirm(cubit.state.selectedMinutes!);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('Xác nhận'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickCustomDuration(BuildContext context) async {
    final cubit = context.read<_PauseDurationCubit>();
    final currentMinutes = cubit.state.customMinutes ?? 30;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
      helpText: 'Chọn thời lượng tạm dừng',
      hourLabelText: 'Giờ',
      minuteLabelText: 'Phút',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked == null || !context.mounted) return;
    cubit.selectCustom(picked.hour * 60 + picked.minute);
  }
}

class _PauseSheetIcon extends StatelessWidget {
  const _PauseSheetIcon();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: const SizedBox.square(
        dimension: 48,
        child: Icon(
          Icons.notifications_paused_outlined,
          color: AppColors.primary,
          size: 24,
        ),
      ),
    );
  }
}

class _DurationOption extends StatelessWidget {
  const _DurationOption({
    required this.value,
    required this.label,
    this.detail,
    this.trailing,
  });

  final int value;
  final String label;
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<int>(
      value: value,
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.darkText,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: detail == null
          ? null
          : Text(
              detail!,
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
      secondary: trailing,
    );
  }
}

class _DurationDivider extends StatelessWidget {
  const _DurationDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 52, color: AppColors.border);
  }
}

String _formatCustomMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours == 0) return '$remainingMinutes phút';
  if (remainingMinutes == 0) return '$hours giờ';
  return '$hours giờ $remainingMinutes phút';
}
