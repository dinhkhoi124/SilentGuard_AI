// lib/features/home/domain/entities/camera_event.dart

import 'package:equatable/equatable.dart';

enum EventLevel { high, medium, normal, info }

enum EventType { fall, still, normal, reconnect }

class CameraEvent extends Equatable {
  const CameraEvent({
    required this.id,
    required this.time,
    required this.title,
    required this.level,
    required this.type,
    required this.room,
    required this.statusLabel,
    this.durationSec,
    this.confidence,
  });

  final String id;
  final String time;
  final String title;
  final EventLevel level;
  final EventType type;
  final String room;
  final String statusLabel;
  final int? durationSec;
  final double? confidence;

  @override
  List<Object?> get props => [id, time, title];
}
