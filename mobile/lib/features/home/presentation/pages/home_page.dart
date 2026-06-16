// lib/features/home/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mobile/features/home/presentation/bloc/home_state.dart';
import 'package:mobile/features/home/presentation/widgets/bottom_nav_bar.dart';
import 'package:mobile/features/home/presentation/widgets/camera_card.dart';
import 'package:mobile/features/home/presentation/widgets/empty_devices.dart';
import 'package:mobile/features/home/presentation/widgets/room_filter_chips.dart';
import 'package:mobile/features/home/presentation/widgets/weather_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 72,
          titleSpacing: 20,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nhà của tôi',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 7),
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
              hasBadge: true,
              onPressed: () =>
                  context.read<HomeBloc>().add(const NotificationTapped()),
            ),
            const SizedBox(width: 14),
          ],
        ),
        body: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            return switch (state) {
              HomeInitial() || HomeLoading() => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              HomeError(:final message) => _ErrorView(message: message),
              HomeLoaded() => _LoadedHome(state: state),
            };
          },
        ),
        floatingActionButton: const _HomeFabs(),
        bottomNavigationBar: const BottomNavBar(),
      ),
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
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
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
                          onAddDevice: () => context.read<HomeBloc>().add(
                            const AddDeviceTapped(),
                          ),
                        )
                      : _InlineDeviceGrid(
                          key: const ValueKey('grid'),
                          devices: state.devices,
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
  const _InlineDeviceGrid({super.key, required this.devices});

  final List<CameraDevice> devices;

  @override
  Widget build(BuildContext context) {
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
                onDelete: (deviceId) =>
                    context.read<HomeBloc>().add(HomeDeviceDeleted(deviceId)),
                onToggleAccessory: (deviceId, accessoryIndex) {
                  context.read<HomeBloc>().add(
                    HomeAccessoryToggled(deviceId, accessoryIndex),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () =>
              context.read<HomeBloc>().add(const AddDeviceTapped()),
          icon: const Icon(Iconsax.add, size: 18),
          label: const Text('Thêm thiết bị'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Tất cả thiết bị',
            style: TextStyle(
              color: AppColors.darkText,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Iconsax.more, color: AppColors.darkText),
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
    this.hasBadge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.darkText,
        minimumSize: const Size(42, 42),
        elevation: 0,
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 21),
          if (hasBadge)
            const Positioned(
              right: -2,
              top: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.badgeRed,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white, width: 1.5),
                  ),
                ),
                child: SizedBox(width: 9, height: 9),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'microphone',
          onPressed: () {},
          tooltip: 'Điều khiển bằng giọng nói',
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          elevation: 3,
          child: const Icon(Iconsax.microphone, size: 20),
        ),
        const SizedBox(height: 10),
        FloatingActionButton(
          heroTag: 'add-device',
          onPressed: () =>
              context.read<HomeBloc>().add(const AddDeviceTapped()),
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
                  context.read<HomeBloc>().add(const HomeStarted()),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
