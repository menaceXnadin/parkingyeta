import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;
  bool _isToggling = false; // Add loading state

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;
  bool get isToggling => _isToggling; // Expose loading state

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadThemeMode();
  }

  // Optimized toggle with immediate UI update
  void toggleTheme() {
    if (_isToggling) return; // Prevent multiple rapid toggles

    _isToggling = true;

    // Update theme immediately for instant UI response
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // Immediate UI update

    // Save to storage asynchronously without blocking UI
    _saveThemeModeAsync().then((_) {
      _isToggling = false;
      notifyListeners();
    });
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return; // No change needed

    _themeMode = mode;
    notifyListeners(); // Immediate update
    _saveThemeModeAsync(); // Async save
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('theme_mode');

      if (savedTheme != null) {
        switch (savedTheme) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'system':
            _themeMode = ThemeMode.system;
            break;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading theme: $e');
      }
      // Fallback to system theme
      _themeMode = ThemeMode.system;
    }

    _isInitialized = true;
    notifyListeners();
  }

  // Async save without blocking UI
  Future<void> _saveThemeModeAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeString;

      switch (_themeMode) {
        case ThemeMode.light:
          themeString = 'light';
          break;
        case ThemeMode.dark:
          themeString = 'dark';
          break;
        case ThemeMode.system:
          themeString = 'system';
          break;
      }

      await prefs.setString('theme_mode', themeString);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving theme: $e');
      }
    }
  }
}
