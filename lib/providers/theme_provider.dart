import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to manage light/dark theme mode with simple persistence.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode_v1';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      switch (value) {
        case 'light':
          _mode = ThemeMode.light;
          break;
        case 'dark':
          _mode = ThemeMode.dark;
          break;
        default:
          _mode = ThemeMode.system;
      }
    } catch (e) {
      debugPrint('ThemeProvider load failed: $e');
      _mode = ThemeMode.system;
    } finally {
      notifyListeners();
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _serialize(mode));
    } catch (e) {
      debugPrint('ThemeProvider save failed: $e');
    }
  }

  Future<void> toggle() async {
    if (_mode == ThemeMode.dark) {
      await setMode(ThemeMode.light);
    } else {
      await setMode(ThemeMode.dark);
    }
  }

  String _serialize(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }
}
