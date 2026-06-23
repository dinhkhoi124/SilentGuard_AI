import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._preferences);

  static const _themeModeKey = 'app_theme_mode';
  static const _lightValue = 'light';
  static const _darkValue = 'dark';
  static const _systemValue = 'system';

  final SharedPreferencesAsync _preferences;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    _themeMode = _themeModeFromValue(
      await _preferences.getString(_themeModeKey),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _preferences.setString(_themeModeKey, _valueFromThemeMode(mode));
  }

  ThemeMode _themeModeFromValue(String? value) {
    return switch (value) {
      _lightValue => ThemeMode.light,
      _darkValue => ThemeMode.dark,
      _systemValue => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  String _valueFromThemeMode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => _lightValue,
      ThemeMode.dark => _darkValue,
      ThemeMode.system => _systemValue,
    };
  }
}
