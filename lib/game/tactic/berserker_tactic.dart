import '../../projectile.dart';
import '../bot_tactic.dart';
import '../game_character.dart';

class BerserkerTactic implements BotTactic {
  double rageMultiplier = 1.0;

  @override
  String get name => 'Berserker';

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) {
    final distance = bot.position.distanceTo(target.position);
    final toTarget = target.position - bot.position;

    // Charge faster when low HP (rage)
    final speedMultiplier = bot.health < 50 ? 2.0 : 1.5;

    bot.velocity.x = toTarget.normalized().x *
        (bot.stats.dexterity / 1.5) * speedMultiplier;
    bot.facingRight = toTarget.x > 0;

    // Attack rapidly when close
    if (bot.attackCooldown <= 0 && distance < bot.stats.attackRange * 35) {
      bot.attack();
      bot.attackCooldown = bot.health < 50 ? 0.3 : 0.6; // Rage = faster attacks
    }
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incoming) {
    // Berserker never evades - tanks through!
    return false;
  }

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    rageMultiplier += 0.1;
    print('${bot.stats.name} bot: RAGE INTENSIFIES! (${rageMultiplier}x)');
  }
}