import 'package:flame/components.dart' show Vector2;

import '../../character_stats.dart';
import '../../game/bot_tactic.dart';
import '../../game/stat/stats.dart';
import '../../managers/resource_manager.dart' hide Vector2;
import '../../player_type.dart';
import 'character_entity.dart';

class CharacterFactory {
  static final ResourceManager _resourceManager = ResourceManager();

  static CharacterEntity create({
    required String characterClass,
    required Vector2 position,
    required PlayerType playerType,
    BotTactic? botTactic,
  }) {
    final stats = _getStatsForClass(characterClass);

    return CharacterEntity(
      position: position,
      stats: stats,
      playerType: playerType,
      botTactic: botTactic,
    );
  }

  static CharacterStats _getStatsForClass(String characterClass) {
    switch (characterClass.toLowerCase()) {
      case 'knight':
        return KnightStats();
      case 'thief':
        return ThiefStats();
      case 'wizard':
        return WizardStats();
      case 'trader':
        return TraderStats();
      default:
        return KnightStats();
    }
  }
}