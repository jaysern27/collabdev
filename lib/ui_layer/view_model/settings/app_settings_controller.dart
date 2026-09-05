import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english,
  chinese,
  malay,
}

class AppSettingsController extends ChangeNotifier {
  AppSettingsController._();

  static final AppSettingsController instance =
  AppSettingsController._();

  static const String _darkModeKey = 'app_dark_mode';
  static const String _languageKey = 'app_language';

  bool _darkMode = false;
  AppLanguage _language = AppLanguage.english;

  bool get darkMode => _darkMode;
  AppLanguage get language => _language;

  String get languageName {
    switch (_language) {
      case AppLanguage.chinese:
        return '中文';
      case AppLanguage.malay:
        return 'Bahasa Melayu';
      case AppLanguage.english:
        return 'English';
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _darkMode = prefs.getBool(_darkModeKey) ?? false;

    final savedLanguage = prefs.getString(_languageKey);

    _language = switch (savedLanguage) {
      'chinese' => AppLanguage.chinese,
      'malay' => AppLanguage.malay,
      _ => AppLanguage.english,
    };
  }

  Future<void> setDarkMode(bool enabled) async {
    if (_darkMode == enabled) {
      return;
    }

    _darkMode = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, enabled);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) {
      return;
    }

    _language = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _languageKey,
      language.name,
    );
  }

  String text({
    required String en,
    required String zh,
    required String ms,
  }) {
    switch (_language) {
      case AppLanguage.chinese:
        return zh;
      case AppLanguage.malay:
        return ms;
      case AppLanguage.english:
        return en;
    }
  }
}
