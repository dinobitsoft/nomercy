import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:nomercy/projectile.dart';

import '../../player_type.dart';
import '../bot_tactic.dart';
import '../game_character.dart';
import '../stat/stats.dart';
import '../tactic/defensive_tactic.dart';

class Wizard extends GameCharacter {
  Wizard({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
  }) : super(
    botTactic: botTactic ?? DefensiveTactic(), // Default: Defensive
    stats: WizardStats(),
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

    // Ranged attack - fireball
    final projectile = Projectile(
      position: position.clone(),
      direction: facingRight ? Vector2(1, 0) : Vector2(-1, 0),
      damage: stats.attackDamage,
      owner: playerType == PlayerType.human ? this as Player : null,
      enemyOwner: playerType == PlayerType.bot ? this as Enemy : null,
      color: Colors.orange,
      type: 'fireball',
    );
    game.add(projectile);
    game.world.add(projectile);
    game.projectiles.add(projectile);
  }
}