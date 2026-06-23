import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/utils/app_colors.dart';
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
              DevicePairingInitial() => const _ProgressView(
                title: 'Chuẩn bị quét mã QR',
                message: 'Đang kiểm tra quyền camera.',
                activeStep: 0,
              ),
              DevicePairingScanning() => const _ScannerView(),
              DevicePairingResolving() => const _ProgressView(
                title: 'Đang xác minh thiết bị',
                message: 'SlientGuard đang gửi mã QR đến máy chủ AI.',
                activeStep: 1,
              ),
              DevicePairingCheckingImou(:final resolvedDevice) => _ProgressView(
                title: 'Đang kiểm tra Imou Cloud',
                message:
                    'Thiết bị ${resolvedDevice.displayName} đã được xác minh bởi SlientGuard.',
                activeStep: 2,
              ),
              DevicePairingObtainingStream(:final imouStatus) => _ProgressView(
                title: 'Đang lấy luồng Imou',
                message: imouStatus.isOnline
                    ? 'Camera ${imouStatus.deviceName ?? imouStatus.serialNumber} đang online.'
                    : 'Camera đang offline — vẫn tiếp tục thêm thiết bị.',
                activeStep: 3,
              ),
              DevicePairingPersisting(:final resolvedDevice) => _ProgressView(
                title: 'Đang lưu thiết bị',
                message:
                    'Đang lưu ${resolvedDevice.displayName} vào máy chủ AI.',
                activeStep: 4,
              ),
              DevicePairingPermissionDenied(:final message) => _MessageView(
                icon: Icons.gpp_bad_outlined,
                title: 'Thiếu quyền truy cập',
                message: message,
                primaryLabel: 'Thử lại',
                onPrimary: () => context.read<DevicePairingBloc>().add(
                  const DevicePairingRetryRequested(),
                ),
                secondaryLabel: 'Mở cài đặt',
                onSecondary: () => context.read<DevicePairingBloc>().add(
                  const DevicePairingOpenSettingsRequested(),
                ),
                tertiaryLabel: 'Chọn ảnh QR',
                onTertiary: () => context.read<DevicePairingBloc>().add(
                  const DevicePairingGalleryQrRequested(),
                ),
              ),
              DevicePairingSuccess(:final device, :final warningMessage) =>
                _MessageView(
                  icon: Icons.check_circle_outline,
                  title: 'Đã thêm camera',
                  message:
                      warningMessage ??
                      '${device.name} đã sẵn sàng phát luồng trực tiếp trong SlientGuard.',
                  primaryLabel: 'Hoàn tất',
                  onPrimary: () => context.pop(device.toCameraDevice()),
                ),
              DevicePairingError(:final message) => _MessageView(
                icon: Icons.warning_amber_rounded,
                title: 'Không thể thêm thiết bị',
                message: message,
                primaryLabel: 'Thử lại',
                onPrimary: () => context.read<DevicePairingBloc>().add(
                  const DevicePairingRetryRequested(),
                ),
                secondaryLabel: 'Chọn ảnh QR',
                onSecondary: () => context.read<DevicePairingBloc>().add(
                  const DevicePairingGalleryQrRequested(),
                ),
              ),
            };
          },
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
          'Nếu đang chạy bằng trình giả lập, hãy chọn ảnh QR từ thư viện.',
          style: TextStyle(
            color: AppColors.mutedText,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => context.read<DevicePairingBloc>().add(
            const DevicePairingGalleryQrRequested(),
          ),
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: const Text('Chọn ảnh QR'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({
    required this.title,
    required this.message,
    required this.activeStep,
  });

  final String title;
  final String message;
  final int activeStep;

  static const _steps = [
    'Quyền truy cập',
    'Xác minh QR',
    'Kiểm tra Imou',
    'Lấy luồng',
    'Lưu thiết bị',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 28),
      children: [
        const _StatusIcon(
          icon: Icons.qr_code_scanner_rounded,
          color: AppColors.primary,
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
        const SizedBox(height: 28),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                for (var index = 0; index < _steps.length; index++)
                  _StepRow(
                    label: _steps[index],
                    isComplete: index < activeStep,
                    isActive: index == activeStep,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.isComplete,
    required this.isActive,
  });

  final String label;
  final bool isComplete;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isComplete || isActive ? AppColors.primary : AppColors.border;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isComplete ? AppColors.primary : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
              shape: BoxShape.circle,
            ),
            child: isComplete
                ? const Icon(Icons.check, color: Colors.white, size: 15)
                : isActive
                ? const Padding(
                    padding: EdgeInsets.all(5),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.darkText : AppColors.mutedText,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.tertiaryLabel,
    this.onTertiary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
      children: [
        _StatusIcon(
          icon: icon,
          color:
              icon == Icons.warning_amber_rounded ||
                  icon == Icons.gpp_bad_outlined
              ? AppColors.destructive
              : AppColors.primary,
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
        const SizedBox(height: 24),
        FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
        ],
        if (tertiaryLabel != null && onTertiary != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onTertiary, child: Text(tertiaryLabel!)),
        ],
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
