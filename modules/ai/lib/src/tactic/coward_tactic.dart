import 'package:engine/engine.dart';

class CowardTactic implements BotTactic {
  @override String get name           => 'Coward';
  @override bool   get isUnupgradable => false;

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) {
    final distance = bot.position.distanceTo(target.position);
    final toTarget = target.position - bot.position;
    bot.facingRight = toTarget.x > 0;
    if (distance < 400) {
      bot.velocity.x = -toTarget.normalized().x * (bot.stats.dexterity / 1.5);
      if (bot.characterState.attackCooldown <= 0 && distance > 300) {
        bot.attack();
        bot.characterState.attackCooldown = 2.0;
      }
    } else {
      bot.velocity.x = 0;
      if (bot.characterState.attackCooldown <= 0) {
        bot.attack();
        bot.characterState.attackCooldown = 1.0;
      }
    }
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incoming) => true;

  @override
  void onDamageTaken(GameCharacter bot, double damage) =>
      print('${bot.stats.name} bot: RUN AWAY!!!');
}
