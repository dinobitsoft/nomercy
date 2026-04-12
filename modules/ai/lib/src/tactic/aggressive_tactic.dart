import 'package:engine/engine.dart';

import '../bot/bot_state.dart';
import '../bot/smart_bot_ai.dart';

class AggressiveTactic implements BotTactic {
  final SmartBotAI ai = SmartBotAI(name: 'Aggressive', personality: BotPersonality.aggressive);

  @override String get name           => ai.name;
  @override bool   get isUnupgradable => false;

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) =>
      ai.executeAI(bot, target, dt);

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incoming) =>
      ai.shouldEvade(bot, incoming);

  @override
  void onDamageTaken(GameCharacter bot, double damage) =>
      ai.onDamageTaken(bot, damage);
}
