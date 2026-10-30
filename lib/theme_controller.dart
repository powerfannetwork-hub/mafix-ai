import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'mafix_theme_mode';

/// App-wide theme state. The selected mode is persisted on this device.
final ValueNotifier<ThemeMode> mafixThemeMode =
    ValueNotifier<ThemeMode>(ThemeMode.dark);

Future<void> loadMafixThemeMode() async {
  final preferences = await SharedPreferences.getInstance();
  final savedMode = preferences.getString(_themeModeKey);
  mafixThemeMode.value = savedMode == 'light' ? ThemeMode.light : ThemeMode.dark;
}

Future<void> setMafixThemeMode(ThemeMode mode) async {
  mafixThemeMode.value = mode;
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(
    _themeModeKey,
    mode == ThemeMode.light ? 'light' : 'dark',
  );
}
