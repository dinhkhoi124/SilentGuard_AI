import 'package:equatable/equatable.dart';

class ImouDeviceStatus extends Equatable {
  const ImouDeviceStatus({
    required this.serialNumber,
    required this.isBound,
    required this.isMine,
    required this.isOnline,
    this.deviceName,
    this.channelCount,
  });

  final String serialNumber;
  final bool isBound;
  final bool isMine;
  final bool isOnline;
  final String? deviceName;
  final int? channelCount;

  @override
  List<Object?> get props => [
    serialNumber,
    isBound,
    isMine,
    isOnline,
    deviceName,
    channelCount,
  ];
}
