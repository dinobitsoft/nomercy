import 'package:engine/engine.dart';

class SniperTactic implements BotTactic {
  @override String get name           => 'Sniper';
  @override bool   get isUnupgradable => false;

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) {
    final distance = bot.position.distanceTo(target.position);
    final toTarget = target.position - bot.position;
    bot.facingRight = toTarget.x > 0;
    if (distance < 600) {
      bot.velocity.x = -toTarget.normalized().x * (bot.stats.dexterity / 2);
    } else {
      bot.velocity.x = 0;
    }
    if (bot.characterState.attackCooldown <= 0 && bot.velocity.x.abs() < 10) {
      bot.attack();
      bot.characterState.attackCooldown = 2.5;
    }
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incoming) =>
      incoming.isNotEmpty;

  @override
  void onDamageTaken(GameCharacter bot, double damage) =>
      print('${bot.stats.name} bot: Repositioning to safer location!');
}
