import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db/app_database.dart';

/// Tiny key-value settings (theme) in SharedPreferences, which is the right
/// tool for small primitives. Relational data lives in SQLite.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs, this._db) {
    final stored = _prefs.getString(_themeKey);
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  static const String _themeKey = 'theme_mode';

  final SharedPreferences _prefs;
  final AppDatabase _db;

  late ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;

  /// Wired in main.dart: signs out and reloads every provider after a reset.
  Future<void> Function()? onDataReset;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> resetDemoData() async {
    await _db.resetDemoData();
    await onDataReset?.call();
  }
}
