import 'dart:math' as math;

import '../../projectile.dart';
import '../bot_tactic.dart';
import '../game_character.dart';

class AggressiveTactic implements BotTactic {
  @override
  String get name => 'Aggressive';

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) {
    final distance = bot.position.distanceTo(target.position);
    final toTarget = target.position - bot.position;

    if (distance < 500) {
      // Always charge towards target
      bot.velocity.x = toTarget.normalized().x * (bot.stats.dexterity / 1.5);
      bot.facingRight = toTarget.x > 0;

      // Jump aggressively
      if (target.position.y < bot.position.y - 50 &&
          bot.groundPlatform != null && !bot.isJumping) {
        bot.velocity.y = -350;
        bot.isJumping = true;
        bot.groundPlatform = null;
      }

      // Attack on cooldown
      if (bot.attackCooldown <= 0 && distance < bot.stats.attackRange * 35) {
        bot.attack();
        bot.attackCooldown = 0.8; // Fast attacks
      }
    }
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incoming) {
    return incoming.isNotEmpty && math.Random().nextDouble() < 0.2; // 20% evade
  }

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    // Become more aggressive when damaged
    print('${bot.stats.name} bot: Taking damage makes me ANGRY!');
  }
}
