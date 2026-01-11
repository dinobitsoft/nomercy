import 'package:flame/components.dart';

import '../../player_type.dart';
import '../bot_tactic.dart';
import '../game_character.dart';
import '../stat/stats.dart';
import '../tactic/aggressive_tactic.dart';

class Knight extends GameCharacter {
  Knight({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
  }) : super(
    botTactic: botTactic ?? AggressiveTactic(), // Default: Aggressive
    stats: KnightStats(),
  );

  @override
  void updateHumanControl(double dt) {
    final joystickDelta = game.joystick.relativeDelta;
    final moveSpeed = stats.dexterity / 2;

    if (joystickDelta.x != 0) {
      velocity.x = joystickDelta.x * moveSpeed * 100;
      facingRight = joystickDelta.x > 0;
    } else {
      velocity.x = 0;
    }

    final joystickDirection = game.joystick.direction;
    if (joystickDirection == JoystickDirection.up && groundPlatform != null) {
      velocity.y = -300;
      groundPlatform = null;
    }
  }

  @override
  void updateBotControl(double dt) {
    if (botTactic != null) {
      botTactic!.execute(this, game.player, dt);
    }
  }

  @override
  void attack() {
    if (attackCooldown > 0) return;
    attackCooldown = 0.5;
    isAttacking = true;
    attackAnimationTimer = 0.2;

    // Melee attack
    for (final enemy in game.enemies) {
      if (position.distanceTo(enemy.position) < stats.attackRange * 30) {
        enemy.takeDamage(stats.attackDamage);
      }
    }
  }
}