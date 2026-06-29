// lib/features/automation/domain/entities/emergency_contact.dart

import 'package:equatable/equatable.dart';

class EmergencyContact extends Equatable {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.priorityOrder,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final int priorityOrder;
  final DateTime createdAt;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    id,
    name,
    phoneNumber,
    priorityOrder,
    createdAt,
    updatedAt,
  ];

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    int? priorityOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      priorityOrder: priorityOrder ?? this.priorityOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
