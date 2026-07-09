// lib/features/household_invite/data/datasources/household_invite_remote_data_source.dart

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/household_invite/domain/entities/household_member.dart';
import 'package:mobile/features/household_invite/domain/entities/invite_request.dart';

abstract class HouseholdInviteRemoteDataSource {
  Future<Map<String, dynamic>> inviteByEmail(String email, String householdId);
  Future<List<InviteRequest>> getPendingInvites();
  Future<void> respondToInvite(String inviteRequestId, bool accepted);
  Future<List<HouseholdMember>> getHouseholdMembers(String householdId);
}

class HouseholdInviteRemoteDataSourceImpl
    implements HouseholdInviteRemoteDataSource {
  const HouseholdInviteRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> inviteByEmail(
    String email,
    String householdId,
  ) async {
    try {
      return await _apiClient.postObject('/api/households/invite-by-email', {
        'email': email,
        'household_id': householdId,
      });
    } catch (e) {
      if (e is ApiException) {
        // Rethrow ApiException to let Cubit read the error message.
        rethrow;
      }
      rethrow;
    }
  }

  @override
  Future<List<InviteRequest>> getPendingInvites() async {
    final response = await _apiClient.getObject(
      '/api/households/invite-requests/pending',
    );
    final itemsList = response['items'] as List<dynamic>? ?? [];
    return itemsList.map((json) => InviteRequest.fromJson(json)).toList();
  }

  @override
  Future<void> respondToInvite(String inviteRequestId, bool accepted) async {
    await _apiClient.postObject(
      '/api/households/invite-requests/$inviteRequestId/respond',
      {'action': accepted ? 'accepted' : 'declined'},
    );
  }

  @override
  Future<List<HouseholdMember>> getHouseholdMembers(String householdId) async {
    final response = await _apiClient.getObject(
      '/api/households/$householdId/members',
    );
    final membersList = response['members'] as List<dynamic>? ?? [];
    return membersList.map((json) => HouseholdMember.fromJson(json)).toList();
  }
}
