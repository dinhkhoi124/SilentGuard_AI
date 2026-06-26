import 'package:equatable/equatable.dart';

sealed class DevicePairingEvent extends Equatable {
  const DevicePairingEvent();

  @override
  List<Object?> get props => [];
}

final class DevicePairingStarted extends DevicePairingEvent {
  const DevicePairingStarted();
}

final class DevicePairingRetryRequested extends DevicePairingEvent {
  const DevicePairingRetryRequested();
}

final class DevicePairingLiveQrDetected extends DevicePairingEvent {
  const DevicePairingLiveQrDetected(this.rawQr);

  final String rawQr;

  @override
  List<Object?> get props => [rawQr];
}
