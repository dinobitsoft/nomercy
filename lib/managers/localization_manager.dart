import 'package:flutter/material.dart';

class LocalizationManager extends ChangeNotifier {
  static final LocalizationManager _instance = LocalizationManager._internal();
  factory LocalizationManager() => _instance;
  LocalizationManager._internal();

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale != locale) {
      _locale = locale;
      notifyListeners();
    }
  }

  static Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'game_title': '2D Action Game',
      'select_character': 'Select Your Character',
      'start_game': 'Start Game',
      'knight': 'Knight',
      'thief': 'Thief',
      'wizard': 'Wizard',
      'trader': 'Trader',
      'settings': 'Settings',
      'language': 'Language',
      'english': 'English',
      'turkish': 'Turkish',
    },
    'tr': {
      'game_title': '2D Aksiyon Oyunu',
      'select_character': 'Karakterini Seç',
      'start_game': 'Oyuna Başla',
      'knight': 'Şövalye',
      'thief': 'Hırsız',
      'wizard': 'Büyücü',
      'trader': 'Tüccar',
      'settings': 'Ayarlar',
      'language': 'Dil',
      'english': 'İngilizce',
      'turkish': 'Türkçe',
    },
  };

  String translate(String key) {
    return _localizedValues[_locale.languageCode]?[key] ?? key;
  }
}

extension LocalizationExtension on BuildContext {
  String translate(String key) => LocalizationManager().translate(key);
}
