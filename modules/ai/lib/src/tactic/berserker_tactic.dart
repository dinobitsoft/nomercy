import 'package:engine/engine.dart';

import '../bot/bot_state.dart';
import '../bot/smart_bot_ai.dart';

class BerserkerTactic implements BotTactic {
  final SmartBotAI ai = SmartBotAI(name: 'Berserker', personality: BotPersonality.berserker);

  @override String get name => ai.name;

  /// Berserkers are never replaced by a wave upgrade.
  @override bool get isUnupgradable => true;

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) =>
      ai.executeAI(bot, target, dt);

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incoming) => false;

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    ai.onDamageTaken(bot, damage);
    print('${bot.stats.name} bot: PAIN MAKES ME STRONGER!');
  }
}
