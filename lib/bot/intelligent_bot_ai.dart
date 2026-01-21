import '../game/game_character.dart';
import '../projectile/projectile.dart';
import 'bot_decision.dart';
import 'bot_state.dart';

abstract class IntelligentBotAI {
  String get name;
  BotPersonality get personality;

  // Core AI method - each bot implements their strategy
  void executeAI(GameCharacter bot, GameCharacter target, double dt);

  // Shared intelligent behaviors
  BotDecision makeDecision(GameCharacter bot, GameCharacter target, List<Projectile> projectiles);
  bool shouldEvade(GameCharacter bot, List<Projectile> incomingProjectiles);
  void onDamageTaken(GameCharacter bot, double damage);
}