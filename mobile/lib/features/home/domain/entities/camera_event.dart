// lib/features/home/domain/entities/camera_event.dart

import 'package:equatable/equatable.dart';

enum EventLevel { high, medium, normal, info }

enum EventType { fall, still, normal, reconnect }

class CameraEvent extends Equatable {
  const CameraEvent({
    required this.id,
    required this.time,
    required this.title,
    required this.description,
    required this.level,
    required this.type,
    this.thumbnailAsset,
  });

  final String id;
  final String time;
  final String title;
  final String description;
  final EventLevel level;
  final EventType type;
  final String? thumbnailAsset;

  @override
  List<Object?> get props => [id, time, title];
}
