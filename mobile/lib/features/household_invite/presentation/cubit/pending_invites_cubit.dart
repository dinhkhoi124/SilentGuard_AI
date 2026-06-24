// lib/features/household_invite/presentation/cubit/pending_invites_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/household_invite/data/datasources/household_invite_remote_data_source.dart';
import 'package:mobile/features/household_invite/domain/entities/invite_request.dart';
import 'package:mobile/features/household_invite/presentation/cubit/pending_invites_state.dart';

class PendingInvitesCubit extends Cubit<PendingInvitesState> {
  PendingInvitesCubit(this._dataSource) : super(const PendingInvitesInitial());

  final HouseholdInviteRemoteDataSource _dataSource;

  Future<void> loadPendingInvites() async {
    emit(const PendingInvitesLoading());
    try {
      final invites = await _dataSource.getPendingInvites();
      if (invites.isEmpty) {
        emit(const PendingInvitesEmpty());
      } else {
        emit(PendingInvitesLoaded(invites));
      }
    } catch (e) {
      emit(const PendingInvitesError('Không thể tải danh sách lời mời.'));
    }
  }

  Future<void> respondToInvite(String inviteRequestId, String action) async {
    List<InviteRequest> currentInvites = [];
    if (state is PendingInvitesLoaded) {
      currentInvites = (state as PendingInvitesLoaded).invites;
    } else if (state is RespondSuccess) {
      currentInvites = (state as RespondSuccess).invites;
    }

    emit(RespondingToInvite(inviteRequestId, currentInvites));

    try {
      await _dataSource.respondToInvite(inviteRequestId, action);

      // Update local list
      final updatedInvites = currentInvites
          .where((i) => i.inviteRequestId != inviteRequestId)
          .toList();
      emit(RespondSuccess(inviteRequestId, action, updatedInvites));

      // We can also re-emit loaded/empty after a short delay so the UI stays clean if we don't depend on Success state to show "Đã chấp nhận"
      // But the requirements say "Replace action buttons with muted text label 'Đã chấp nhận'".
      // This means we might want to keep it in the list locally for a moment, or rely on a local cache.
      // For now, emit RespondSuccess and the UI can handle the visual transition.
    } catch (e) {
      emit(
        PendingInvitesError(
          'Không thể phản hồi lời mời. Vui lòng thử lại.',
          currentInvites,
        ),
      );
      emit(PendingInvitesLoaded(currentInvites)); // Revert
    }
  }
}
