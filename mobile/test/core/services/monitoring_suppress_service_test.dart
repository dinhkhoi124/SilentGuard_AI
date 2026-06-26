// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/services/monitoring_suppress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;
  late MonitoringSuppressService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    service = MonitoringSuppressService(sharedPreferences: preferences);
  });

  test('suppresses and resumes one camera independently', () async {
    await service.suppress('camera-a', 15);

    expect(await service.isSuppressed('camera-a'), isTrue);
    expect(await service.isSuppressed('camera-b'), isFalse);

    await service.resume('camera-a');

    expect(await service.isSuppressed('camera-a'), isFalse);
  });

  test('removes expired entries when read', () async {
    final key = MonitoringSuppressService.storageKeyFor('camera-a');
    await preferences.setString(
      key,
      DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
    );

    expect(await service.getSuppressedUntil('camera-a'), isNull);
    expect(preferences.containsKey(key), isFalse);
  });

  test('pruneExpired removes malformed and expired values', () async {
    final expiredKey = MonitoringSuppressService.storageKeyFor('expired');
    final malformedKey = MonitoringSuppressService.storageKeyFor('malformed');
    final activeKey = MonitoringSuppressService.storageKeyFor('active');
    await preferences.setString(
      expiredKey,
      DateTime.now()
          .toUtc()
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
    );
    await preferences.setString(malformedKey, 'not-a-date');
    await preferences.setString(
      activeKey,
      DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
    );

    await service.pruneExpired();

    expect(preferences.containsKey(expiredKey), isFalse);
    expect(preferences.containsKey(malformedKey), isFalse);
    expect(preferences.containsKey(activeKey), isTrue);
  });

  test('clearAll removes only monitoring suppression entries', () async {
    final cameraKey = MonitoringSuppressService.storageKeyFor('camera-a');
    await preferences.setString(cameraKey, DateTime.now().toIso8601String());
    await preferences.setString('unrelated_preference', 'keep-me');

    await service.clearAll();

    expect(preferences.containsKey(cameraKey), isFalse);
    expect(preferences.getString('unrelated_preference'), 'keep-me');
  });
}
