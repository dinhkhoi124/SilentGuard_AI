import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/utils/app_colors.dart';
import 'package:mobile/core/widgets/app_empty_state.dart';
import 'package:mobile/features/devices/domain/entities/paired_device.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_bloc.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_event.dart';
import 'package:mobile/features/devices/presentation/bloc/device_pairing_state.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class DevicePairingPage extends StatelessWidget {
  const DevicePairingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Thêm thiết bị',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(false),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          tooltip: 'Quay lại',
        ),
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<DevicePairingBloc, DevicePairingState>(
          builder: (context, state) {
            return switch (state) {
              DevicePairingInitial() => const _InitialView(),
              DevicePairingScanning() => const _ScannerView(),
              DevicePairingLoading(:final serialNumber) => _LoadingView(
                serialNumber: serialNumber,
              ),
              DevicePairingSuccess(:final device) => _SuccessView(
                device: device,
              ),
              DevicePairingError(:final message) => _ErrorView(
                message: message,
              ),
            };
          },
        ),
      ),
    );
  }
}

class _InitialView extends StatelessWidget {
  const _InitialView();

  @override
  Widget build(BuildContext context) {
    return const _MessageLayout(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Quét QR camera',
      message: 'Đang chuẩn bị camera để đọc mã serial trên thiết bị.',
      child: Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.serialNumber});

  final String serialNumber;

  @override
  Widget build(BuildContext context) {
    return _MessageLayout(
      icon: Icons.cloud_upload_outlined,
      title: 'Đang đăng ký camera',
      message: 'Serial: $serialNumber',
      child: const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.device});

  final PairedDevice device;

  @override
  Widget build(BuildContext context) {
    return _MessageLayout(
      icon: Icons.check_circle_outline_rounded,
      title: 'Đã thêm camera',
      message: device.name,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: FilledButton(
          onPressed: () => context.pop(true),
          child: const Text('Xong'),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AppEmptyState(
          icon: message == 'Không có kết nối mạng'
              ? Icons.wifi_off_rounded
              : Icons.warning_amber_rounded,
          title: message == 'Không có kết nối mạng'
              ? 'Chưa kết nối mạng'
              : 'Không thể thêm thiết bị',
          message: message,
          primaryActionLabel: 'Thử lại',
          onPrimaryAction: () => context.read<DevicePairingBloc>().add(
            const DevicePairingRetryRequested(),
          ),
        ),
      ),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  late final MobileScannerController _controller;
  bool _handledScan = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (_handledScan) return;
                    final rawValue = capture.barcodes
                        .map((barcode) => barcode.rawValue)
                        .whereType<String>()
                        .firstOrNull;
                    if (rawValue == null || rawValue.trim().isEmpty) return;
                    _handledScan = true;
                    context.read<DevicePairingBloc>().add(
                      DevicePairingLiveQrDetected(rawValue.trim()),
                    );
                  },
                ),
                const _ScanFrame(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Quét mã QR trên camera',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ứng dụng sẽ lấy serial từ QR và đăng ký camera với máy chủ SilentGuard.',
          style: TextStyle(
            color: AppColors.mutedText,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _MessageLayout extends StatelessWidget {
  const _MessageLayout({
    required this.icon,
    required this.title,
    required this.message,
    this.child,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isError = icon == Icons.warning_amber_rounded;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
      children: [
        _StatusIcon(
          icon: icon,
          color: isError ? AppColors.destructive : AppColors.primary,
        ),
        const SizedBox(height: 22),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.darkText,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(
            color: AppColors.mutedText,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        ?child,
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox.square(
        dimension: 62,
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
