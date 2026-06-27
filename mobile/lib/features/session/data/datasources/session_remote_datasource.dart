import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/session/domain/entities/backend_user.dart';
import 'package:mobile/features/session/domain/entities/household.dart';

abstract interface class SessionRemoteDataSource {
  Future<BackendUser> login({String? inviteCode});
  Future<Household> getCurrentHousehold();
  Future<void> logout({String? idToken});
  Future<void> switchHousehold(String householdId);
}

class SessionRemoteDataSourceImpl implements SessionRemoteDataSource {
  const SessionRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  static const _loginTimeout = Duration(
    seconds: 35,
  ); // FIX: Render free tier cold starts can take longer than the default API timeout.

  @override
  Future<BackendUser> login({String? inviteCode}) async {
    final response = await _apiClient.postObject(
      '/api/users/login',
      null,
      _inviteHeaders(inviteCode),
      _loginTimeout, // FIX: only the backend session login gets the extended cold-start timeout.
    );
    final user = response['user'];
    if (user is Map<String, dynamic>) {
      return _backendUserFromJson(user);
    }
    if (user is Map) {
      return _backendUserFromJson(Map<String, dynamic>.from(user));
    }
    if (response.containsKey('id')) {
      return _backendUserFromJson(response);
    }

    throw const ApiException(
      'Phản hồi đăng nhập từ máy chủ không hợp lệ.',
      kind: ApiExceptionKind.invalidResponse,
    );
  }

  @override
  Future<Household> getCurrentHousehold() async {
    final response = await _apiClient.getObject('/api/households/me');
    return _householdFromJson(response);
  }

  @override
  Future<void> switchHousehold(String householdId) async {
    await _apiClient.postObject('/api/users/switch-household', {
      'household_id': householdId,
    });
  }

  @override
  Future<void> logout({String? idToken}) async {
    final extraHeaders = idToken != null && idToken.isNotEmpty
        ? {'Authorization': 'Bearer $idToken'}
        : null;
    await _apiClient.postObject(
      '/api/users/logout',
      null,
      extraHeaders,
      const Duration(
        seconds: 5,
      ), // short timeout so it doesn't block local logout long if awaited
    );
  }

  Map<String, String>? _inviteHeaders(String? inviteCode) {
    final trimmed = inviteCode?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return {'X-Invite-Code': trimmed};
  }

  BackendUser _backendUserFromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: _requiredString(json, 'id'),
      firebaseUid: _requiredString(json, 'firebase_uid', fallbackKey: 'uid'),
      fullName: _optionalString(json, 'full_name'),
      email: _requiredString(json, 'email'),
      role: _requiredString(json, 'role'),
    );
  }

  Household _householdFromJson(Map<String, dynamic> json) {
    return Household(
      householdId: _requiredString(json, 'household_id'),
      role: _requiredString(json, 'role'),
      elderlyName: _optionalString(json, 'elderly_name'),
    );
  }

  String _requiredString(
    Map<String, dynamic> json,
    String key, {
    String? fallbackKey,
  }) {
    final value = json[key] ?? (fallbackKey == null ? null : json[fallbackKey]);
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;

    throw ApiException(
      'Phản hồi máy chủ thiếu trường $key.',
      kind: ApiExceptionKind.invalidResponse,
    );
  }

  String _optionalString(Map<String, dynamic> json, String key) {
    return json[key]?.toString().trim() ?? '';
  }
}
