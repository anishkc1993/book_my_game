import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  static const String _themeModeKey = 'theme_mode';

  final SharedPreferences _prefs;

  AppThemeType _currentThemeType;
  ThemeMode _themeMode;

  ThemeProvider({
    required SharedPreferences prefs,
    AppThemeType initialTheme = AppThemeType.purple,
    ThemeMode initialMode = ThemeMode.system,
  })  : _prefs = prefs,
        _currentThemeType = initialTheme,
        _themeMode = initialMode {
    _loadSavedPreferences();
  }

  /// Current theme type
  AppThemeType get currentThemeType => _currentThemeType;

  /// Current theme mode (light/dark/system)
  ThemeMode get themeMode => _themeMode;

  /// Get the current AppTheme
  AppTheme get currentTheme => AppTheme(type: _currentThemeType);

  /// Light theme data
  ThemeData get lightTheme => currentTheme.lightTheme;

  /// Dark theme data
  ThemeData get darkTheme => currentTheme.darkTheme;

  /// All available themes
  List<AppThemeType> get availableThemes => AppThemeType.values.toList();

  /// Load saved preferences
  void _loadSavedPreferences() {
    final savedThemeIndex = _prefs.getInt(_themeKey);
    if (savedThemeIndex != null && savedThemeIndex < AppThemeType.values.length) {
      _currentThemeType = AppThemeType.values[savedThemeIndex];
    }

    final savedModeIndex = _prefs.getInt(_themeModeKey);
    if (savedModeIndex != null && savedModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[savedModeIndex];
    }

    notifyListeners();
  }

  /// Set theme type
  Future<void> setThemeType(AppThemeType type) async {
    if (_currentThemeType == type) return;

    _currentThemeType = type;
    await _prefs.setInt(_themeKey, type.index);
    notifyListeners();
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    await _prefs.setInt(_themeModeKey, mode.index);
    notifyListeners();
  }

  /// Toggle between light and dark mode
  Future<void> toggleThemeMode() async {
    final newMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await setThemeMode(newMode);
  }

  /// Check if current mode is dark
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }
}
