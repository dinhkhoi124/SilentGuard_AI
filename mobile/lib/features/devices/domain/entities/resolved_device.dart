import 'package:equatable/equatable.dart';

class ResolvedDevice extends Equatable {
  const ResolvedDevice({
    required this.deviceId,
    required this.displayName,
    required this.serialNumber,
    this.model,
    this.productId,
    this.location,
    this.metadata = const {},
  });

  final String deviceId;
  final String displayName;
  final String serialNumber;
  final String? model;
  final String? productId;
  final String? location;
  final Map<String, dynamic> metadata;

  @override
  List<Object?> get props => [
    deviceId,
    displayName,
    serialNumber,
    model,
    productId,
    location,
    metadata,
  ];
}
