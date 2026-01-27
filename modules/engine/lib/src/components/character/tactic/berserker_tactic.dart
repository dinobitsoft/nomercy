import 'package:engine/engine.dart';

class BerserkerTactic implements BotTactic {
  final SmartBotAI ai = SmartBotAI(
    name: 'Berserker',
    personality: BotPersonality.berserker,
  );

  @override
  String get name => ai.name;

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) {
    ai.executeAI(bot, target, dt);
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incomingProjectiles) {
    return false; // Berserker never evades
  }

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    ai.onDamageTaken(bot, damage);
    print('${bot.stats.name} bot: PAIN MAKES ME STRONGER!');
  }
}