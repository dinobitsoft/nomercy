import '../../bot/bot_state.dart';
import '../../bot/smart_bot_ai.dart';
import '../../entities/projectile/projectile.dart';
import '../bot_tactic.dart';
import '../game_character.dart';

class BalancedTactic implements BotTactic {
  final SmartBotAI ai = SmartBotAI(
    name: 'Balanced',
    personality: BotPersonality.balanced,
  );

  @override
  String get name => ai.name;

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) {
    ai.executeAI(bot, target, dt);
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incomingProjectiles) {
    return ai.shouldEvade(bot, incomingProjectiles);
  }

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    ai.onDamageTaken(bot, damage);
  }
}