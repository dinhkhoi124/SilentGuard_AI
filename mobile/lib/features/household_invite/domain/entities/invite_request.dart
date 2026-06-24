// lib/features/household_invite/domain/entities/invite_request.dart

import 'package:equatable/equatable.dart';

class InviteRequest extends Equatable {
  const InviteRequest({
    required this.inviteRequestId,
    required this.householdId,
    required this.householdName,
    required this.inviterName,
    required this.inviterEmail,
    required this.createdAt,
  });

  final String inviteRequestId;
  final String householdId;
  final String householdName;
  final String inviterName;
  final String inviterEmail;
  final DateTime createdAt;

  factory InviteRequest.fromJson(Map<String, dynamic> json) {
    return InviteRequest(
      inviteRequestId: json['invite_request_id']?.toString() ?? '',
      householdId: json['household_id']?.toString() ?? '',
      householdName: json['household_name']?.toString() ?? '',
      inviterName: json['inviter_name']?.toString() ?? '',
      inviterEmail: json['inviter_email']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    inviteRequestId,
    householdId,
    householdName,
    inviterName,
    inviterEmail,
    createdAt,
  ];
}
