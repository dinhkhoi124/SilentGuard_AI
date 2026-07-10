import 'dart:developer' as developer;

import 'package:mobile/core/services/local_notification_service.dart';
import 'package:mobile/features/session/domain/repositories/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyReportNotificationService {
  DailyReportNotificationService({
    required SharedPreferences sharedPreferences,
    required LocalNotificationService localNotificationService,
    required SessionRepository sessionRepository,
  }) : _sharedPreferences = sharedPreferences,
       _localNotificationService = localNotificationService,
       _sessionRepository = sessionRepository;

  static const _enabledKey = 'daily_report_notification_enabled';

  final SharedPreferences _sharedPreferences;
  final LocalNotificationService _localNotificationService;
  final SessionRepository _sessionRepository;

  bool get isEnabled => _sharedPreferences.getBool(_enabledKey) ?? true;

  Future<bool> setEnabled(bool enabled) async {
    await _sharedPreferences.setBool(_enabledKey, enabled);
    if (!enabled) {
      await _localNotificationService.cancelDailyReportReminder();
      return true;
    }
    return syncSchedule();
  }

  Future<bool> syncSchedule() async {
    if (!isEnabled) {
      await _localNotificationService.cancelDailyReportReminder();
      return true;
    }

    final householdId = _sessionRepository.currentHouseholdId;
    if (householdId == null || householdId.isEmpty) {
      developer.log(
        'Daily report notification skipped: no active household.',
        name: 'DailyReportNotificationService',
      );
      return false;
    }

    developer.log(
      'syncSchedule called. householdId=$householdId',
      name: 'DailyReportNotificationService',
    );
    return _localNotificationService.scheduleDailyReportReminder();
  }
}
