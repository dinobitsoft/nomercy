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

  static final Map<String, Map<String, String>> _localizedValues = {
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
      'russian': 'Russian',
      'single_player': 'SINGLE PLAYER',
      'multiplayer': 'MULTIPLAYER',
      'upgrade': 'UPGRADE',
      'gamepad_ready': 'GAMEPAD READY',
      'no_gamepad': 'NO GAMEPAD',
      'select_mode': 'Select Game Mode',
      'survival': 'Survival',
      'survival_desc': 'Endless waves of enemies\nHow long can you survive?',
      'campaign': 'Campaign',
      'campaign_desc': 'Story mode with boss fights\nComplete all waves!',
      'boss_fight': 'Boss Fight',
      'boss_fight_desc': 'Face a powerful boss\nCan you defeat it?',
      'training': 'Training',
      'training_desc': 'Practice mode\nPerfect your skills',
      'select_map': 'Select Map',
      'procedural_maps': 'Procedural Maps',
      'premade_maps': 'Pre-made Maps',
      'map_style': 'Map Style',
      'difficulty': 'Difficulty',
      'custom_seed': 'Custom Seed (optional):',
      'random_hint': 'Random',
      'generate_play': 'GENERATE & PLAY',
      'level': 'Level',
      'easy': 'EASY',
      'medium': 'MEDIUM',
      'hard': 'HARD',
      'expert': 'EXPERT',
      'arena': 'Arena',
      'arena_desc': 'Open combat\nzone',
      'platformer': 'Platformer',
      'platformer_desc': 'Vertical\nchallenge',
      'dungeon': 'Dungeon',
      'dungeon_desc': 'Rooms &\ncorridors',
      'towers': 'Towers',
      'towers_desc': 'Sky-high\nbattle',
      'chaos': 'Chaos',
      'chaos_desc': 'Random\nmadness',
      'balanced': 'Balanced',
      'balanced_desc': 'Mixed\nlayout',
      'weapon': 'Weapon',
      'pwr': 'PWR',
      'mag': 'MAG',
      'dex': 'DEX',
      'int': 'INT',
      'combo': 'COMBO!',
      'atk': 'ATK',
    },
    'ru': {
      'game_title': '2D Экшен-игра',
      'select_character': 'Выберите персонажа',
      'start_game': 'Начать игру',
      'knight': 'Рыцарь',
      'thief': 'Вор',
      'wizard': 'Маг',
      'trader': 'Торговец',
      'settings': 'Настройки',
      'language': 'Язык',
      'english': 'Английский',
      'russian': 'Русский',
      'single_player': 'ОДИНОЧНАЯ ИГРА',
      'multiplayer': 'МУЛЬТИПЛЕЕР',
      'upgrade': 'УЛУЧШЕНИЕ',
      'gamepad_ready': 'ГЕЙМПАД ГОТОВ',
      'no_gamepad': 'НЕТ ГЕЙМПАДА',
      'select_mode': 'Выберите режим',
      'survival': 'Выживание',
      'survival_desc': 'Бесконечные волны врагов\nКак долго вы продержитесь?',
      'campaign': 'Кампания',
      'campaign_desc': 'Сюжетный режим с боссами\nПройдите все волны!',
      'boss_fight': 'Битва с боссом',
      'boss_fight_desc': 'Сразитесь с мощным боссом\nСможете победить?',
      'training': 'Тренировка',
      'training_desc': 'Режим практики\nОтточите свои навыки',
      'select_map': 'Выберите карту',
      'procedural_maps': 'Случайные карты',
      'premade_maps': 'Готовые карты',
      'map_style': 'Стиль карты',
      'difficulty': 'Сложность',
      'custom_seed': 'Свой сид (опционально):',
      'random_hint': 'Случайно',
      'generate_play': 'СОЗДАТЬ И ИГРАТЬ',
      'level': 'Уровень',
      'easy': 'ЛЕГКО',
      'medium': 'СРЕДНЕ',
      'hard': 'ТЯЖЕЛО',
      'expert': 'ЭКСПЕРТ',
      'arena': 'Арена',
      'arena_desc': 'Открытая зона\nбоя',
      'platformer': 'Платформер',
      'platformer_desc': 'Вертикальное\nиспытание',
      'dungeon': 'Подземелье',
      'dungeon_desc': 'Комнаты и\nкоридоры',
      'towers': 'Башни',
      'towers_desc': 'Высотная\nбитва',
      'chaos': 'Хаос',
      'chaos_desc': 'Случайное\nбезумие',
      'balanced': 'Баланс',
      'balanced_desc': 'Смешанная\nпланировка',
      'weapon': 'Оружие',
      'pwr': 'СИЛ',
      'mag': 'МАГ',
      'dex': 'ЛОВ',
      'int': 'ИНТ',
      'combo': 'КОМБО!',
      'atk': 'АТК',
    },
  };

  String translate(String key) {
    return _localizedValues[_locale.languageCode]?[key] ?? key;
  }
}

extension LocalizationExtension on BuildContext {
  String translate(String key) => LocalizationManager().translate(key);
}
