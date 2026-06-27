// lib/features/household_invite/presentation/cubit/pending_invites_state.dart

import 'package:equatable/equatable.dart';
import 'package:mobile/features/household_invite/domain/entities/invite_request.dart';

abstract class PendingInvitesState extends Equatable {
  const PendingInvitesState();

  @override
  List<Object?> get props => [];
}

class PendingInvitesInitial extends PendingInvitesState {
  const PendingInvitesInitial();
}

class PendingInvitesLoading extends PendingInvitesState {
  const PendingInvitesLoading();
}

class PendingInvitesLoaded extends PendingInvitesState {
  const PendingInvitesLoaded(this.invites);

  final List<InviteRequest> invites;

  @override
  List<Object?> get props => [invites];
}

class PendingInvitesEmpty extends PendingInvitesState {
  const PendingInvitesEmpty();
}

class RespondingToInvite extends PendingInvitesState {
  const RespondingToInvite(this.inviteRequestId, this.previousInvites);

  final String inviteRequestId;
  final List<InviteRequest> previousInvites;

  @override
  List<Object?> get props => [inviteRequestId, previousInvites];
}

class RespondSuccess extends PendingInvitesState {
  const RespondSuccess(this.inviteRequestId, this.action, this.invites);

  final String inviteRequestId;
  final String action; // 'accepted' or 'declined'
  final List<InviteRequest> invites;

  @override
  List<Object?> get props => [inviteRequestId, action, invites];
}

class PendingInvitesError extends PendingInvitesState {
  const PendingInvitesError(this.message, [this.previousInvites = const []]);

  final String message;
  final List<InviteRequest> previousInvites;

  @override
  List<Object?> get props => [message, previousInvites];
}
