// lib/features/home/presentation/pages/home_page.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/core/theme/app_spacing.dart';
import 'package:mobile/core/widgets/wave_text_loader.dart';
import 'package:mobile/features/auth/presentation/bloc/auth_bloc.dart'; // FIX: session-expired UI needs to trigger sign-out.
import 'package:mobile/features/auth/presentation/bloc/auth_event.dart'; // FIX: reuse existing logout event instead of changing router/auth logic.
import 'package:mobile/features/automation/presentation/pages/automation_page.dart';
import 'package:mobile/features/account/presentation/pages/account_page.dart';
import 'package:mobile/features/reports/presentation/pages/reports_page.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mobile/features/home/presentation/bloc/home_state.dart';
import 'package:mobile/features/home/presentation/widgets/bottom_nav_bar.dart';
import 'package:mobile/features/home/presentation/widgets/camera_card.dart';
import 'package:mobile/features/home/presentation/widgets/empty_devices.dart';
import 'package:mobile/features/home/presentation/widgets/room_filter_chips.dart';
import 'package:mobile/features/home/presentation/widgets/weather_card.dart';
import 'package:mobile/features/notifications/domain/entities/notification_alert.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:mobile/features/video_upload/presentation/bloc/video_upload_bloc.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeBloc>().add(const HomeStarted());
    });
  }

  static const _tabTitles = ['Nhà của tôi', 'Tự động', 'Báo cáo', 'Tài khoản'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : AppColors.darkText;
    return BlocListener<VideoUploadBloc, VideoUploadState>(
      listenWhen: (previous, current) =>
          current is VideoUploadSuccess || current is VideoUploadFailure,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
        if (state is VideoUploadSuccess) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Đã gửi video thành công! Chúng tôi sẽ thông báo nếu phát hiện bất thường.',
              ),
              backgroundColor: AppColors.darkText,
            ),
          );
        } else if (state is VideoUploadFailure) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('❌ Gửi video thất bại. Vui lòng thử lại.'),
              backgroundColor: AppColors.badgeRed,
            ),
          );
        }
        context.read<VideoUploadBloc>().add(const VideoUploadResetRequested());
      },
      child: BlocListener<NotificationsCubit, NotificationsState>(
        listenWhen: (previous, current) =>
            previous.revision != current.revision &&
            current.latestDelivery == NotificationDelivery.foreground &&
            current.latestAlert != null,
        listener: (context, state) {
          final alert = state.latestAlert;
          if (alert == null) return;
          _showForegroundAlert(context, alert);
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {},
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 72,
              titleSpacing: 20,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tabTitles[_selectedTab],
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
              ),
              actions: [
                _TopBarButton(
                  icon: Iconsax.cpu,
                  tooltip: 'Trợ lý AI',
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
                _TopBarButton(
                  icon: Iconsax.notification,
                  tooltip: 'Thông báo',
                  badgeLabel: context.select((NotificationsCubit cubit) {
                    final count = cubit.state.unreadCount;
                    if (count == 0) return null;
                    return count > 9 ? '9+' : count.toString();
                  }),
                  onPressed: () => context.push('/notifications'),
                ),
                const SizedBox(width: 14),
              ],
            ),
            body: BlocBuilder<VideoUploadBloc, VideoUploadState>(
              builder: (context, uploadState) {
                final uploadInProgress = uploadState is VideoUploadLoading;
                return Stack(
                  children: [
                    IndexedStack(
                      index: _selectedTab,
                      children: const [
                        _HomeTab(),
                        AutomationPage(),
                        ReportsPage(),
                        AccountPage(),
                      ],
                    ),
                    if (uploadInProgress)
                      const Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        child: LinearProgressIndicator(minHeight: 3),
                      ),
                  ],
                );
              },
            ),
            floatingActionButton: _selectedTab == 0 ? const _HomeFabs() : null,
            bottomNavigationBar: BottomNavBar(
              selectedIndex: _selectedTab,
              uploadDisabled: context.select(
                (VideoUploadBloc bloc) => bloc.state is VideoUploadLoading,
              ),
              onSelected: (index) => setState(() => _selectedTab = index),
              onUploadSelected: () {
                context.read<VideoUploadBloc>().add(
                  const VideoUploadSubmitRequested(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showForegroundAlert(BuildContext context, NotificationAlert alert) {
    final cameraId = alert.cameraId;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${alert.displayTitle}: ${alert.displayBody}'),
          backgroundColor: AppColors.darkText,
          action: cameraId == null || cameraId.isEmpty
              ? null
              : SnackBarAction(
                  label: 'Xem',
                  textColor: Colors.white,
                  onPressed: () {
                    context.read<NotificationsCubit>().markRead(alert.id);
                    context.go('/camera/${Uri.encodeComponent(cameraId)}');
                  },
                ),
        ),
      );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listenWhen: (previous, current) =>
          current is HomeLoaded && current.openPairingFlow,
      listener: (context, state) {
        context.push('/add-device').then((_) {
          if (!context.mounted) return;
          context.read<HomeBloc>().add(const HomeStarted());
        });
      },
      builder: (context, state) {
        return switch (state) {
          HomeInitial() || HomeLoading() => const WaveTextLoader(),
          HomeBackendWarmingUp() =>
            const _BackendWarmingView(), // FIX: Render cold start is a waiting state, not an error.
          HomeUnauthorized(:final message) => _SessionExpiredView(
            message: message,
          ), // FIX: show session-expired UI only for auth failures.
          HomeError(:final message) => _ErrorView(message: message),
          CameraStreamUrlLoading() ||
          CameraStreamUrlLoaded() ||
          CameraStreamUrlFailure() => const WaveTextLoader(),
          HomeLoaded() => _LoadedHome(state: state),
        };
      },
    );
  }
}

class _LoadedHome extends StatelessWidget {
  const _LoadedHome({required this.state});

  final HomeLoaded state;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              6,
              AppSpacing.pagePadding,
              120,
            ),
            sliver: SliverList.list(
              children: [
                WeatherCard(weather: state.weather),
                const SizedBox(height: 28),
                const _DevicesHeader(),
                const SizedBox(height: 16),
                RoomFilterChips(
                  selectedRoom: state.selectedRoom,
                  onSelected: (room) =>
                      context.read<HomeBloc>().add(RoomFilterChanged(room)),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: state.devices.isEmpty
                      ? _EmptyDeviceSection(
                          key: const ValueKey('empty'),
                          onAddDevice: () => _handleAddDevicePressed(context),
                        )
                      : _InlineDeviceGrid(
                          key: const ValueKey('grid'),
                          devices: state.devices,
                          cameraThumbnails: state.cameraThumbnails,
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

class _EmptyDeviceSection extends StatelessWidget {
  const _EmptyDeviceSection({super.key, required this.onAddDevice});

  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 40),
      child: EmptyDevices(onAddDevice: onAddDevice),
    );
  }
}

class _InlineDeviceGrid extends StatelessWidget {
  const _InlineDeviceGrid({
    super.key,
    required this.devices,
    required this.cameraThumbnails,
  });

  final List<CameraDevice> devices;
  final Map<String, Uint8List> cameraThumbnails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                    child: child,
                  ),
                );
              },
              child: CameraCard(
                key: ValueKey(device.id),
                device: device,
                thumbnailBytes: cameraThumbnails[device.id],
                onDelete: (deviceId) =>
                    context.read<HomeBloc>().add(HomeDeviceDeleted(deviceId)),
                onToggleAccessory: (deviceId, accessoryIndex) {
                  context.read<HomeBloc>().add(
                    HomeAccessoryToggled(deviceId, accessoryIndex),
                  );
                },
                onThumbnailCaptured: (bytes) {
                  context.read<HomeBloc>().add(
                    CameraThumbnailCaptured(deviceId: device.id, bytes: bytes),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _handleAddDevicePressed(context),
          icon: const Icon(Iconsax.add, size: 18),
          label: const Text('Thêm thiết bị'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: const StadiumBorder(),
            textStyle: theme.textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class _DevicesHeader extends StatelessWidget {
  const _DevicesHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? theme.colorScheme.onSurface
        : AppColors.darkText;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Tất cả thiết bị',
            style: theme.textTheme.titleLarge?.copyWith(color: titleColor),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Iconsax.more, color: titleColor),
          tooltip: 'Tùy chọn thiết bị',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeLabel,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? theme.colorScheme.surface
        : AppColors.surface;
    final foregroundColor = isDark
        ? theme.colorScheme.onSurface
        : AppColors.darkText;
    final badgeBorderColor = isDark ? theme.colorScheme.surface : Colors.white;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: const Size(42, 42),
        elevation: 0,
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 21),
          if (badgeLabel != null)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.badgeRed,
                  borderRadius: const BorderRadius.all(Radius.circular(9)),
                  border: Border.fromBorderSide(
                    BorderSide(color: badgeBorderColor, width: 1.5),
                  ),
                ),
                child: Text(
                  badgeLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeFabs extends StatelessWidget {
  const _HomeFabs();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryFabBackground = isDark
        ? theme.colorScheme.surface
        : AppColors.surface;
    final secondaryFabForeground = isDark
        ? theme.colorScheme.primary
        : AppColors.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'microphone',
          onPressed: () {},
          tooltip: 'Điều khiển bằng giọng nói',
          backgroundColor: secondaryFabBackground,
          foregroundColor: secondaryFabForeground,
          elevation: 3,
          child: const Icon(Iconsax.microphone, size: 20),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'add-device',
          onPressed: () => _handleAddDevicePressed(context),
          tooltip: 'Thêm thiết bị',
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 5,
          child: const Icon(Iconsax.add),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.warning_2, color: AppColors.badgeRed, size: 36),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () =>
                  context.read<HomeBloc>().add(const HomeRetryRequested()),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackendWarmingView extends StatelessWidget {
  // FIX: friendly non-dismissable UI while backend wakes up.
  const _BackendWarmingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? theme.colorScheme.onSurface : AppColors.darkText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(height: 18),
            Text(
              'Đang kết nối máy chủ, vui lòng chờ giây lát…',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionExpiredView extends StatelessWidget {
  // FIX: separate real auth failure UI from backend warm-up UI.
  const _SessionExpiredView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? theme.colorScheme.onSurface : AppColors.darkText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.warning_2, color: AppColors.badgeRed, size: 36),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.read<AuthBloc>().add(
                // FIX: logout option for definitive unauthorized state.
                const AuthSignOutRequested(),
              ),
              child: const Text('Đăng nhập lại'),
            ),
          ],
        ),
      ),
    );
  }
}

void _handleAddDevicePressed(BuildContext context) {
  unawaited(_openPairingFlow(context));
}

Future<void> _openPairingFlow(BuildContext context) async {
  await context.push('/add-device');
  if (!context.mounted) return;
  context.read<HomeBloc>().add(const HomeStarted());
}
