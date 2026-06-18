import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  OnboardingService(this._preferences);

  static const _completedKey = 'onboarding_completed';

  final SharedPreferencesAsync _preferences;

  Future<bool> isCompleted() async {
    return await _preferences.getBool(_completedKey) ?? false;
  }

  Future<void> markCompleted() {
    return _preferences.setBool(_completedKey, true);
  }
}
