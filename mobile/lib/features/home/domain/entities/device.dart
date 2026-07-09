import 'package:equatable/equatable.dart';

class Device extends Equatable {
  const Device({
    required this.id,
    required this.name,
    required this.room,
    required this.isOnline,
  });

  final String id;
  final String name;
  final String room;
  final bool isOnline;

  @override
  List<Object?> get props => [id, name, room, isOnline];
}
