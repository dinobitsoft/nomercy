import '../../projectile.dart';
import '../bot_tactic.dart';
import '../game_character.dart';

class SniperTactic implements BotTactic {
  @override
  String get name => 'Sniper';

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) {
    final distance = bot.position.distanceTo(target.position);
    final toTarget = target.position - bot.position;

    // Always maintain maximum range
    if (distance < 600) {
      bot.velocity.x = -toTarget.normalized().x * (bot.stats.dexterity / 2);
      bot.facingRight = toTarget.x > 0;
    } else {
      // Perfect sniper range - stay still
      bot.velocity.x = 0;
      bot.facingRight = toTarget.x > 0;
    }

    // Only shoot when standing still
    if (bot.attackCooldown <= 0 && bot.velocity.x.abs() < 10) {
      bot.attack();
      bot.attackCooldown = 2.5; // Slow, accurate shots
    }
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incoming) {
    // Always evade - snipers are fragile
    return incoming.isNotEmpty;
  }

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    print('${bot.stats.name} bot: Repositioning to safer location!');
  }
}