// lib/features/household_invite/presentation/cubit/pending_invites_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mobile/features/household_invite/data/datasources/household_invite_remote_data_source.dart';
import 'package:mobile/features/household_invite/domain/entities/invite_request.dart';
import 'package:mobile/features/household_invite/presentation/cubit/pending_invites_state.dart';
import 'package:mobile/features/notifications/data/datasources/notification_local_data_source.dart';
import 'package:mobile/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';

class PendingInvitesCubit extends Cubit<PendingInvitesState> {
  PendingInvitesCubit(
    this._dataSource,
    this._notificationLocalDataSource,
    this._notificationsCubit,
    this._sessionRepository,
    this._homeBloc,
  ) : super(const PendingInvitesInitial());

  final HouseholdInviteRemoteDataSource _dataSource;
  final NotificationLocalDataSource _notificationLocalDataSource;
  final NotificationsCubit _notificationsCubit;
  final SessionRepository _sessionRepository;
  final HomeBloc _homeBloc;

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

  Future<void> respondToInvite(String inviteRequestId, bool accepted) async {
    final action = accepted ? 'accepted' : 'declined';
    List<InviteRequest> currentInvites = [];
    if (state is PendingInvitesLoaded) {
      currentInvites = (state as PendingInvitesLoaded).invites;
    } else if (state is RespondSuccess) {
      currentInvites = (state as RespondSuccess).invites;
    }

    emit(RespondingToInvite(inviteRequestId, currentInvites));

    try {
      await _dataSource.respondToInvite(inviteRequestId, accepted);

      // Update local list
      final updatedInvites = currentInvites
          .where((i) => i.inviteRequestId != inviteRequestId)
          .toList();
      emit(RespondSuccess(inviteRequestId, action, updatedInvites));

      try {
        await _notificationLocalDataSource.removeNotificationByInviteRequestId(
          inviteRequestId,
        );
        _notificationsCubit.removeByInviteRequestId(inviteRequestId);

        if (action == 'accepted') {
          try {
            final invite = currentInvites.firstWhere(
              (i) => i.inviteRequestId == inviteRequestId,
            );
            await _sessionRepository.switchHousehold(invite.householdId);
          } catch (_) {
            // fallback if invite is somehow missing
            _sessionRepository.clearCachedSession();
            await _sessionRepository.provisionSession();
          }
          _homeBloc.add(const HomeStarted());
        }
      } catch (_) {
        // Log error but do not emit error state since action succeeded
      }
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
