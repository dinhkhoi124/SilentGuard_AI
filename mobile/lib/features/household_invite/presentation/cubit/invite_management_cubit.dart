// lib/features/household_invite/presentation/cubit/invite_management_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/household_invite/data/datasources/household_invite_remote_data_source.dart';
import 'package:mobile/features/household_invite/domain/entities/invite_exceptions.dart';
import 'package:mobile/features/household_invite/presentation/cubit/invite_management_state.dart';
import 'package:mobile/injection_container.dart';

class InviteManagementCubit extends Cubit<InviteManagementState> {
  InviteManagementCubit(this._dataSource)
    : super(const InviteManagementInitial());

  final HouseholdInviteRemoteDataSource _dataSource;

  Future<void> loadMembers(String householdId) async {
    emit(const InviteManagementLoading());
    try {
      final members = await _dataSource.getHouseholdMembers(householdId);
      emit(InviteManagementLoaded(members));
    } catch (e) {
      emit(const InviteManagementError('Không thể tải danh sách thành viên.'));
    }
  }

  Future<void> inviteByEmail(String email, String householdId) async {
    final prevState = state; // Save to restore if needed
    emit(const InviteEmailSearching());
    try {
      final response = await _dataSource.inviteByEmail(email, householdId);
      final inviteeName = response['invitee_name']?.toString() ?? 'Người dùng';
      emit(InviteEmailSuccess(inviteeName));
      // Reload members in background to potentially show invited status (if API returns it)
      if (prevState is InviteManagementLoaded) {
        await loadMembers(householdId);
      }
    } on InviteUserNotFoundException {
      emit(const InviteEmailError('Email này chưa có tài khoản SilentGuard.'));
    } on InviteAlreadyMemberException {
      emit(const InviteEmailError('Người dùng này đã là thành viên.'));
    } on InviteAlreadyPendingException {
      emit(const InviteEmailError('Đã có lời mời đang chờ xác nhận.'));
    } on ApiException catch (e) {
      emit(InviteEmailError(e.message));
    } catch (e) {
      emit(const InviteEmailError('Đã có lỗi xảy ra. Vui lòng thử lại.'));
    }
  }

}
