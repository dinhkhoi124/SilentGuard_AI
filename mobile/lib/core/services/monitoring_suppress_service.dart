import 'package:shared_preferences/shared_preferences.dart';

class MonitoringSuppressService {
  MonitoringSuppressService({required SharedPreferencesAsync sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  static const String _keyPrefix = 'suppress_camera_';

  final SharedPreferencesAsync _sharedPreferences;

  static String storageKeyFor(String cameraId) {
    return '$_keyPrefix${cameraId.trim()}';
  }

  Future<void> suppress(String cameraId, int durationMinutes) async {
    final normalizedCameraId = cameraId.trim();
    if (normalizedCameraId.isEmpty || durationMinutes <= 0) return;

    final suppressedUntil = DateTime.now().toUtc().add(
      Duration(minutes: durationMinutes),
    );
    await _sharedPreferences.setString(
      storageKeyFor(normalizedCameraId),
      suppressedUntil.toIso8601String(),
    );
  }

  Future<void> resume(String cameraId) async {
    final normalizedCameraId = cameraId.trim();
    if (normalizedCameraId.isEmpty) return;
    await _sharedPreferences.remove(storageKeyFor(normalizedCameraId));
  }

  Future<DateTime?> getSuppressedUntil(String cameraId) async {
    final normalizedCameraId = cameraId.trim();
    if (normalizedCameraId.isEmpty) return null;

    final key = storageKeyFor(normalizedCameraId);
    final storedValue = await _sharedPreferences.getString(key);
    final suppressedUntil = DateTime.tryParse(storedValue ?? '')?.toUtc();
    if (suppressedUntil == null ||
        !suppressedUntil.isAfter(DateTime.now().toUtc())) {
      if (storedValue != null) await _sharedPreferences.remove(key);
      return null;
    }
    return suppressedUntil;
  }

  Future<bool> isSuppressed(String cameraId) async {
    return await getSuppressedUntil(cameraId) != null;
  }

  Future<void> pruneExpired() async {
    final keys = await _sharedPreferences.getKeys();
    final suppressKeys = keys.where((key) => key.startsWith(_keyPrefix));
    final now = DateTime.now().toUtc();

    for (final key in suppressKeys) {
      final storedValue = await _sharedPreferences.getString(key);
      final suppressedUntil = DateTime.tryParse(storedValue ?? '')?.toUtc();
      if (suppressedUntil == null || !suppressedUntil.isAfter(now)) {
        await _sharedPreferences.remove(key);
      }
    }
  }

  Future<void> clearAll() async {
    final keys = await _sharedPreferences.getKeys();
    final suppressKeys = keys
        .where((key) => key.startsWith(_keyPrefix))
        .toSet();
    if (suppressKeys.isEmpty) return;
    await _sharedPreferences.clear(allowList: suppressKeys);
  }

  static Future<bool> isSuppressedInBackground({
    required SharedPreferencesAsync sharedPreferences,
    required String cameraId,
  }) async {
    final normalizedCameraId = cameraId.trim();
    if (normalizedCameraId.isEmpty) return false;

    final key = storageKeyFor(normalizedCameraId);
    final storedValue = await sharedPreferences.getString(key);
    final suppressedUntil = DateTime.tryParse(storedValue ?? '')?.toUtc();
    if (suppressedUntil == null ||
        !suppressedUntil.isAfter(DateTime.now().toUtc())) {
      if (storedValue != null) await sharedPreferences.remove(key);
      return false;
    }
    return true;
  }
}
