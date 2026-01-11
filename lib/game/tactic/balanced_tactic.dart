import 'dart:math' as math;

import 'package:flame/components.dart';

import '../../projectile.dart';
import '../bot_tactic.dart';
import '../game_character.dart';

class BalancedTactic implements BotTactic {
  @override
  String get name => 'Balanced';

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) {
    final distance = bot.position.distanceTo(target.position);
    final toTarget = target.position - bot.position;

    if (distance < 200) {
      // Close - back up a bit
      bot.velocity.x = -toTarget.normalized().x * (bot.stats.dexterity / 2.5);
      bot.facingRight = toTarget.x > 0;
    } else if (distance < 400) {
      // Medium - strafe
      final perpendicular = Vector2(-toTarget.y, toTarget.x).normalized();
      bot.velocity.x = perpendicular.x * (bot.stats.dexterity / 2.5);
      bot.facingRight = toTarget.x > 0;
    } else {
      // Far - advance
      bot.velocity.x = toTarget.normalized().x * (bot.stats.dexterity / 2);
      bot.facingRight = toTarget.x > 0;
    }

    // Balanced attack rate
    if (bot.attackCooldown <= 0 && distance < bot.stats.attackRange * 30) {
      bot.attack();
      bot.attackCooldown = 1.2;
    }
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incoming) {
    return incoming.isNotEmpty && math.Random().nextDouble() < 0.5; // 50% evade
  }

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    print('${bot.stats.name} bot: Adjusting strategy...');
  }
}

// Coward Tactic - Run away, only shoot when safe
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