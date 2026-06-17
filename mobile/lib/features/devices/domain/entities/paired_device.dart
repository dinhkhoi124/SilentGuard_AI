import 'package:equatable/equatable.dart';
import 'package:mobile/features/home/domain/entities/camera_device.dart';

class PairedDevice extends Equatable {
  const PairedDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.rtspUrl,
    required this.location,
    required this.status,
    required this.isArmed,
    required this.accessories,
    required this.accessoryStates,
    this.model,
    this.serialNumber,
    this.productId,
  });

  final String id;
  final String name;
  final String ipAddress;
  final String rtspUrl;
  final String location;
  final String status;
  final bool isArmed;
  final List<String> accessories;
  final List<bool> accessoryStates;
  final String? model;
  final String? serialNumber;
  final String? productId;

  CameraDevice toCameraDevice() {
    return CameraDevice(
      id: id,
      name: name,
      location: location,
      status: status,
      isArmed: isArmed,
      accessories: accessories,
      accessoryStates: accessoryStates,
      ipAddress: ipAddress,
      rtspUrl: rtspUrl,
      model: model,
      serialNumber: serialNumber,
      productId: productId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    ipAddress,
    rtspUrl,
    location,
    status,
    isArmed,
    accessories,
    accessoryStates,
    model,
    serialNumber,
    productId,
  ];
}
