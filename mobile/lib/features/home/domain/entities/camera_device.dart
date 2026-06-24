// lib/features/home/domain/entities/camera_device.dart

import 'package:equatable/equatable.dart';

class CameraDevice extends Equatable {
  const CameraDevice({
    required this.id,
    required this.name,
    required this.location,
    required this.status,
    required this.isArmed,
    required this.accessories,
    required this.accessoryStates,
    this.ipAddress,
    this.rtspUrl,
    this.model,
    this.serialNumber,
    this.productId,
    this.room,
  });

  final String id;
  final String name;
  final String location;
  final String status;
  final bool isArmed;
  final List<String> accessories;
  final List<bool> accessoryStates;
  final String? ipAddress;
  final String? rtspUrl;
  final String? model;
  final String? serialNumber;
  final String? productId;

  /// Raw backend room key (e.g. 'bedroom', 'living_room').
  /// Distinct from [location] which is the human-readable display string.
  final String? room;

  CameraDevice copyWith({
    List<bool>? accessoryStates,
    bool? isArmed,
    String? ipAddress,
    String? rtspUrl,
    String? model,
    String? serialNumber,
    String? productId,
    String? room,
  }) {
    return CameraDevice(
      id: id,
      name: name,
      location: location,
      status: status,
      isArmed: isArmed ?? this.isArmed,
      accessories: accessories,
      accessoryStates: accessoryStates ?? this.accessoryStates,
      ipAddress: ipAddress ?? this.ipAddress,
      rtspUrl: rtspUrl ?? this.rtspUrl,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      productId: productId ?? this.productId,
      room: room ?? this.room,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    location,
    status,
    isArmed,
    accessories,
    accessoryStates,
    ipAddress,
    rtspUrl,
    model,
    serialNumber,
    productId,
    room,
  ];
}
