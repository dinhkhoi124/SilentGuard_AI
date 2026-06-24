// lib/features/automation/data/models/emergency_contact_model.dart

import 'package:mobile/features/automation/domain/entities/emergency_contact.dart';

class EmergencyContactModel extends EmergencyContact {
  const EmergencyContactModel({
    required super.id,
    required super.name,
    required super.phoneNumber,
    required super.priorityOrder,
    required super.createdAt,
    super.updatedAt,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String,
      priorityOrder: json['priority_order'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'priority_order': priorityOrder,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  factory EmergencyContactModel.fromEntity(EmergencyContact entity) {
    return EmergencyContactModel(
      id: entity.id,
      name: entity.name,
      phoneNumber: entity.phoneNumber,
      priorityOrder: entity.priorityOrder,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
