import 'package:equatable/equatable.dart';

class OnvifDiscoveryResult extends Equatable {
  const OnvifDiscoveryResult({
    required this.serviceUrl,
    required this.ipAddress,
    required this.scopes,
    this.serialNumber,
    this.hardwareId,
  });

  final String serviceUrl;
  final String ipAddress;
  final List<String> scopes;
  final String? serialNumber;
  final String? hardwareId;

  bool matchesSerial(String serial) {
    final normalizedSerial = serial.trim().toLowerCase();
    if (normalizedSerial.isEmpty) return false;

    final ownSerial = serialNumber?.trim().toLowerCase();
    if (ownSerial == normalizedSerial) return true;

    return scopes.any(
      (scope) => scope.toLowerCase().contains(normalizedSerial),
    );
  }

  @override
  List<Object?> get props => [
    serviceUrl,
    ipAddress,
    scopes,
    serialNumber,
    hardwareId,
  ];
}
