import 'dart:math' as math;

import '../../projectile.dart';
import '../bot_tactic.dart';
import '../game_character.dart';

class DefensiveTactic implements BotTactic {
  @override
  String get name => 'Defensive';

  @override
  void execute(GameCharacter bot, GameCharacter target, double dt) {
    final distance = bot.position.distanceTo(target.position);
    final toTarget = target.position - bot.position;

    // Maintain safe distance
    final optimalRange = bot.stats.attackRange * 25;

    if (distance < optimalRange - 100) {
      // Too close - retreat
      bot.velocity.x = -toTarget.normalized().x * (bot.stats.dexterity / 2);
      bot.facingRight = toTarget.x > 0;
    } else if (distance > optimalRange + 100) {
      // Too far - advance slowly
      bot.velocity.x = toTarget.normalized().x * (bot.stats.dexterity / 3);
      bot.facingRight = toTarget.x > 0;
    } else {
      // Good range - stay and shoot
      bot.velocity.x = 0;
      bot.facingRight = toTarget.x > 0;
    }

    // Attack when in good position
    if (bot.attackCooldown <= 0 && distance < bot.stats.attackRange * 30) {
      bot.attack();
      bot.attackCooldown = 1.5; // Slower, careful attacks
    }
  }

  @override
  bool shouldEvade(GameCharacter bot, List<Projectile> incoming) {
    return incoming.isNotEmpty && math.Random().nextDouble() < 0.7; // 70% evade
  }

  @override
  void onDamageTaken(GameCharacter bot, double damage) {
    print('${bot.stats.name} bot: Retreating to safety!');
  }
}