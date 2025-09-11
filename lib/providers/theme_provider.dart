import 'package:flutter/material.dart';
import '../core/services/local_storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final LocalStorageService _localStorage = LocalStorageService();

  ThemeMode _themeMode = ThemeMode.system;
  String _selectedLanguage = 'en';

  // Getters
  ThemeMode get themeMode => _themeMode;
  String get selectedLanguage => _selectedLanguage;

  // Initialize theme provider
  Future<void> initialize() async {
    await _loadThemeMode();
    await _loadLanguage();
  }

  // Load theme mode from storage
  Future<void> _loadThemeMode() async {
    try {
      final themeString = _localStorage.getThemeMode();
      switch (themeString) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
        default:
          _themeMode = ThemeMode.system;
          break;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
    }
  }

  // Load language from storage
  Future<void> _loadLanguage() async {
    try {
      _selectedLanguage = _localStorage.getLanguage();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading language: $e');
    }
  }

  // Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    
    String themeString;
    switch (mode) {
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
    
    await _localStorage.setThemeMode(themeString);
    notifyListeners();
  }

  // Set language
  Future<void> setLanguage(String languageCode) async {
    _selectedLanguage = languageCode;
    await _localStorage.setLanguage(languageCode);
    notifyListeners();
  }

  // Toggle between light and dark theme
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  // Check if current theme is dark
  bool isDarkMode(BuildContext context) {
    switch (_themeMode) {
      case ThemeMode.light:
        return false;
      case ThemeMode.dark:
        return true;
      case ThemeMode.system:
        return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
  }

  // Get current theme mode as string
  String get themeModeString {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  // Get available languages
  List<Map<String, String>> get availableLanguages => [
    {'code': 'en', 'name': 'English'},
    {'code': 'es', 'name': 'Español'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'de', 'name': 'Deutsch'},
    {'code': 'hi', 'name': 'हिन्दी'},
    {'code': 'ar', 'name': 'العربية'},
  ];

  // Get language name by code
  String getLanguageName(String code) {
    final language = availableLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'code': code, 'name': code.toUpperCase()},
    );
    return language['name']!;
  }
}
