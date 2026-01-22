import '../../entities/projectile/projectile.dart';
import '../bot_tactic.dart';
import '../game_character.dart';

class CowardTactic implements BotTactic {
  @override
  String get name => 'Coward';

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) {
    final distance = bot.position.distanceTo(target.position);
    final toTarget = target.position - bot.position;

    if (distance < 400) {
      // Run away!
      bot.velocity.x = -toTarget.normalized().x * (bot.stats.dexterity / 1.5);
      bot.facingRight = toTarget.x > 0;

      // Only attack while retreating if far enough
      if (bot.attackCooldown <= 0 && distance > 300) {
        bot.attack();
        bot.attackCooldown = 2.0; // Slow attacks
      }
    } else {
      // Safe distance - stop and shoot
      bot.velocity.x = 0;
      bot.facingRight = toTarget.x > 0;

      if (bot.attackCooldown <= 0) {
        bot.attack();
        bot.attackCooldown = 1.0;
      }
    }
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incoming) {
    return true; // Always try to evade!
  }

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    print('${bot.stats.name} bot: RUN AWAY!!!');
  }
}