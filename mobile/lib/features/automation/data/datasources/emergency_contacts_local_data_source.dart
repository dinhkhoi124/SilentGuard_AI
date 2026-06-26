// lib/features/automation/data/datasources/emergency_contacts_local_data_source.dart

import 'dart:convert';
import 'package:mobile/features/automation/data/models/emergency_contact_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class EmergencyContactsLocalDataSource {
  Future<List<EmergencyContactModel>> getContacts();
  Future<void> saveContacts(List<EmergencyContactModel> contacts);
}

class EmergencyContactsLocalDataSourceImpl
    implements EmergencyContactsLocalDataSource {
  const EmergencyContactsLocalDataSourceImpl(this._preferences);

  final SharedPreferences _preferences;
  static const _key = 'local_emergency_contacts';

  @override
  Future<List<EmergencyContactModel>> getContacts() async {
    final jsonString = _preferences.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map(
            (json) =>
                EmergencyContactModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveContacts(List<EmergencyContactModel> contacts) async {
    final jsonList = contacts.map((c) => c.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _preferences.setString(_key, jsonString);
  }
}
