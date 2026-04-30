import 'package:flutter/material.dart';

/// Holds the current theme mode. Backed by an in-memory value (persistence
/// can be added later — keep a single source of truth here so the rest of
/// the app reads through this one notifier).
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void cycle() {
    switch (_mode) {
      case ThemeMode.system:
        setMode(ThemeMode.light);
      case ThemeMode.light:
        setMode(ThemeMode.dark);
      case ThemeMode.dark:
        setMode(ThemeMode.system);
    }
  }
}
