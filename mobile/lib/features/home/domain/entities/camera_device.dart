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
  });

  final String id;
  final String name;
  final String location;
  final String status;
  final bool isArmed;
  final List<String> accessories;
  final List<bool> accessoryStates;

  CameraDevice copyWith({List<bool>? accessoryStates, bool? isArmed}) {
    return CameraDevice(
      id: id,
      name: name,
      location: location,
      status: status,
      isArmed: isArmed ?? this.isArmed,
      accessories: accessories,
      accessoryStates: accessoryStates ?? this.accessoryStates,
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
  ];
}
