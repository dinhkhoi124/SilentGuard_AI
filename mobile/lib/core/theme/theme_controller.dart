import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._preferences);

  static const _themeModeKey = 'app_theme_mode';
  static const _lightValue = 'light';
  static const _darkValue = 'dark';
  static const _systemValue = 'system';

  final SharedPreferences _preferences;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    // Không await để tách khỏi main thread startup block
    _loadAsync();
  }

  Future<void> _loadAsync() async {
    try {
      final loadedMode = _themeModeFromValue(
        _preferences.getString(_themeModeKey),
      );
      if (loadedMode == _themeMode) return;
      _themeMode = loadedMode;
      notifyListeners();
    } catch (e) {
      // Keystore/crypto lỗi trên một số thiết bị Android — giữ nguyên default theme
      debugPrint('[ThemeController] Failed to load theme preference: $e');
    }
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
