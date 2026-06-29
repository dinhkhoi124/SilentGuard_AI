import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonitoringSuppressService {
  MonitoringSuppressService({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  static const String _keyPrefix = 'suppress_camera_';

  final SharedPreferences _sharedPreferences;

  static String storageKeyFor(String cameraId) {
    return '$_keyPrefix${cameraId.trim()}';
  }

  Future<void> suppress(String cameraId, int durationMinutes) async {
    try {
      final normalizedCameraId = cameraId.trim();
      if (normalizedCameraId.isEmpty || durationMinutes <= 0) return;

      final suppressedUntil = DateTime.now().toUtc().add(
        Duration(minutes: durationMinutes),
      );
      await _sharedPreferences
          .setString(
            storageKeyFor(normalizedCameraId),
            suppressedUntil.toIso8601String(),
          )
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[MonitoringSuppressService] suppress failed: $e');
    }
  }

  Future<void> resume(String cameraId) async {
    try {
      final normalizedCameraId = cameraId.trim();
      if (normalizedCameraId.isEmpty) return;
      await _sharedPreferences
          .remove(storageKeyFor(normalizedCameraId))
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[MonitoringSuppressService] resume failed: $e');
    }
  }

  Future<DateTime?> getSuppressedUntil(String cameraId) async {
    try {
      final normalizedCameraId = cameraId.trim();
      if (normalizedCameraId.isEmpty) return null;

      final key = storageKeyFor(normalizedCameraId);
      final storedValue = _sharedPreferences.getString(key);
      final suppressedUntil = DateTime.tryParse(storedValue ?? '')?.toUtc();
      if (suppressedUntil == null ||
          !suppressedUntil.isAfter(DateTime.now().toUtc())) {
        if (storedValue != null) {
          await _sharedPreferences
              .remove(key)
              .timeout(const Duration(seconds: 1));
        }
        return null;
      }
      return suppressedUntil;
    } catch (e) {
      debugPrint('[MonitoringSuppressService] getSuppressedUntil failed: $e');
      return null;
    }
  }

  Future<bool> isSuppressed(String cameraId) async {
    try {
      return await getSuppressedUntil(cameraId) != null;
    } catch (e) {
      debugPrint('[MonitoringSuppressService] isSuppressed failed: $e');
      return false;
    }
  }

  Future<void> pruneExpired() async {
    try {
      final keys = _sharedPreferences.getKeys();
      final suppressKeys = keys.where((key) => key.startsWith(_keyPrefix));
      final now = DateTime.now().toUtc();
      for (final key in suppressKeys) {
        final storedValue = _sharedPreferences.getString(key);
        final suppressedUntil = DateTime.tryParse(storedValue ?? '')?.toUtc();
        if (suppressedUntil == null || !suppressedUntil.isAfter(now)) {
          await _sharedPreferences
              .remove(key)
              .timeout(const Duration(seconds: 1));
        }
      }
    } catch (e) {
      debugPrint(
        '[MonitoringSuppressService] pruneExpired failed (Keystore issue?): $e',
      );
      // Không crash app — suppress state sẽ tự expire tự nhiên theo thời gian
    }
  }

  Future<void> clearAll() async {
    try {
      final keys = _sharedPreferences.getKeys();
      final suppressKeys = keys
          .where((key) => key.startsWith(_keyPrefix))
          .toSet();
      if (suppressKeys.isEmpty) return;
      for (final key in suppressKeys) {
        await _sharedPreferences
            .remove(key)
            .timeout(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('[MonitoringSuppressService] clearAll failed: $e');
    }
  }

  static Future<bool> isSuppressedInBackground({
    required SharedPreferences sharedPreferences,
    required String cameraId,
  }) async {
    try {
      final normalizedCameraId = cameraId.trim();
      if (normalizedCameraId.isEmpty) return false;

      final key = storageKeyFor(normalizedCameraId);
      final storedValue = sharedPreferences.getString(key);
      final suppressedUntil = DateTime.tryParse(storedValue ?? '')?.toUtc();
      if (suppressedUntil == null ||
          !suppressedUntil.isAfter(DateTime.now().toUtc())) {
        if (storedValue != null) {
          await sharedPreferences
              .remove(key)
              .timeout(const Duration(seconds: 1));
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint(
        '[MonitoringSuppressService] isSuppressedInBackground failed: $e',
      );
      return false;
    }
  }
}
