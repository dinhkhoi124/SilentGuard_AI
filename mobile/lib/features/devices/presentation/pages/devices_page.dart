// lib/features/devices/presentation/pages/devices_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/features/devices/presentation/bloc/devices_bloc.dart';
import 'package:mobile/features/devices/presentation/bloc/devices_event.dart';
import 'package:mobile/features/devices/presentation/bloc/devices_state.dart';
import 'package:mobile/features/devices/presentation/widgets/camera_card.dart';
import 'package:mobile/injection_container.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Thiết bị của tôi',
          style: TextStyle(
            color: AppColors.darkText,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          tooltip: 'Quay lại',
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: BlocProvider(
        create: (_) => sl<DevicesBloc>()..add(const DevicesStarted()),
        child: BlocBuilder<DevicesBloc, DevicesState>(
          builder: (context, state) {
            if (state is! DevicesLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: state.devices.length,
              itemBuilder: (context, index) {
                return CameraCard(device: state.devices[index]);
              },
            );
          },
        ),
      ),
    );
  }
}
