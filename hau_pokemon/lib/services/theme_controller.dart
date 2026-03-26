import 'package:flutter/material.dart';

class AppThemeController {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  bool get isDark => mode.value == ThemeMode.dark;

  void toggle() {
    mode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }

  void setMode(ThemeMode themeMode) {
    mode.value = themeMode;
  }
}