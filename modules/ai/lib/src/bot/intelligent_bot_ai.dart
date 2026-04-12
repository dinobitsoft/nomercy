import 'package:engine/engine.dart';

import 'bot_decision.dart';
import 'bot_state.dart';

abstract class IntelligentBotAI {
  String get name;
  BotPersonality get personality;

  void executeAI(GameCharacter bot, GameCharacter target, double dt);
  BotDecision makeDecision(GameCharacter bot, GameCharacter target,
      List<Projectile> projectiles);
  bool shouldEvade(GameCharacter bot, List<Projectile> incomingProjectiles);
  void onDamageTaken(GameCharacter bot, double damage);
}
