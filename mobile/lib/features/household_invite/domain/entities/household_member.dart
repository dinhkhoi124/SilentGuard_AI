// lib/features/household_invite/domain/entities/household_member.dart

import 'package:equatable/equatable.dart';

class HouseholdMember extends Equatable {
  const HouseholdMember({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.joinedAt,
    required this.isInContacts,
    this.contactsPriority,
  });

  final String userId;
  final String fullName;
  final String email;
  final String role;
  final DateTime joinedAt;
  final bool isInContacts;
  final int? contactsPriority;

  factory HouseholdMember.fromJson(Map<String, dynamic> json) {
    return HouseholdMember(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      joinedAt:
          DateTime.tryParse(json['joined_at']?.toString() ?? '') ??
          DateTime.now(),
      isInContacts: json['is_in_contacts'] == true,
      contactsPriority: json['contacts_priority'] as int?,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    fullName,
    email,
    role,
    joinedAt,
    isInContacts,
    contactsPriority,
  ];
}
