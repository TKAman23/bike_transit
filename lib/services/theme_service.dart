import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App theme mode, persisted on the device only (decision Q2).
class ThemeService extends ChangeNotifier {
  ThemeService(this._prefs) {
    final stored = _prefs.getString(_key);
    _mode = ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  static const _key = 'themeMode';
  final SharedPreferences _prefs;
  late ThemeMode _mode;

  ThemeMode get mode => _mode;

  bool isDark(BuildContext context) => switch (_mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      };

  Future<void> setDark(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _prefs.setString(_key, _mode.name);
  }
}
