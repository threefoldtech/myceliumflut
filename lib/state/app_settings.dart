import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _kThemeModeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  AppSettings() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeModeKey);
    if (saved != null) {
      _themeMode = ThemeMode.values.firstWhere((m) => m.toString() == saved, orElse: () => ThemeMode.light);
      notifyListeners();
    }
  }

  Future<void> toggleDark(bool enabled) async {
    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _themeMode.toString());
  }
}

final appSettingsProvider = ChangeNotifierProvider<AppSettings>((ref) {
  return AppSettings();
});


