// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light; // Default to light mode

  ThemeMode get themeMode => _themeMode;

  void setTheme(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners(); // This notifies any listening widgets to rebuild
  }
}
