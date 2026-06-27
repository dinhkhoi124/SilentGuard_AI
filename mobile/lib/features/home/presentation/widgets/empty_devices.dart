import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile/core/widgets/app_empty_state.dart';

class EmptyDevices extends StatelessWidget {
  const EmptyDevices({super.key, required this.onAddDevice});

  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Iconsax.camera,
      title: 'Chưa có camera nào',
      message: 'Thêm camera để bắt đầu giám sát an toàn cho người thân.',
      primaryActionLabel: 'Thêm thiết bị',
      onPrimaryAction: onAddDevice,
      compact: false,
    );
  }
}
