import 'package:mobile/features/home/domain/entities/device.dart';

class DeviceModel extends Device {
  const DeviceModel({
    required super.id,
    required super.name,
    required super.room,
    required super.isOnline,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
    id: json['id'] as String,
    name: json['name'] as String,
    room: json['room'] as String,
    isOnline: json['isOnline'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'room': room,
    'isOnline': isOnline,
  };
}
