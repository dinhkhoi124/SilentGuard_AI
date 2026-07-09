// lib/features/household_invite/presentation/cubit/invite_management_state.dart

import 'package:equatable/equatable.dart';
import 'package:mobile/features/household_invite/domain/entities/household_member.dart';

abstract class InviteManagementState extends Equatable {
  const InviteManagementState();

  @override
  List<Object?> get props => [];
}

class InviteManagementInitial extends InviteManagementState {
  const InviteManagementInitial();
}

class InviteManagementLoading extends InviteManagementState {
  const InviteManagementLoading();
}

class InviteManagementLoaded extends InviteManagementState {
  const InviteManagementLoaded(this.members);

  final List<HouseholdMember> members;

  @override
  List<Object?> get props => [members];
}

class InviteEmailSearching extends InviteManagementState {
  const InviteEmailSearching();
}

class InviteEmailSuccess extends InviteManagementState {
  const InviteEmailSuccess(this.inviteeName);

  final String inviteeName;

  @override
  List<Object?> get props => [inviteeName];
}

class InviteEmailError extends InviteManagementState {
  const InviteEmailError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class InviteManagementError extends InviteManagementState {
  const InviteManagementError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
