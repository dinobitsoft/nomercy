import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:nomercy/projectile/projectile.dart';

import '../../player_type.dart';
import '../bot_tactic.dart';
import '../game_character.dart';
import '../stat/stats.dart';
import '../tactic/balanced_tactic.dart';


class Thief extends GameCharacter {
  Thief({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
  }) : super(
    botTactic: botTactic ?? BalancedTactic(),
    stats: ThiefStats(),
  );

  @override
  void updateHumanControl(double dt) {
    // Skip if stunned, landing recovery, or dodge rolling
    if (isStunned || isLanding || isDodging) return;

    final joystickDelta = game.joystick.relativeDelta;
    final moveSpeed = stats.dexterity / 2;

    // Thief has better mobility during attack commit
    final moveMultiplier = isAttackCommitted ? 0.5 : 1.0;

    if (joystickDelta.x != 0 && !isBlocking) {
      velocity.x = joystickDelta.x * moveSpeed * 100 * moveMultiplier;
      facingRight = joystickDelta.x > 0;
    } else if (!isAttackCommitted && !isBlocking) {
      velocity.x *= 0.7;
    }

    // Block with down input
    if (joystickDelta.y > 0.5 && groundPlatform != null) {
      startBlock();
      velocity.x = 0;
    } else {
      stopBlock();
    }

    // Jump - Thief has lower jump stamina cost (more agile)
    final joystickDirection = game.joystick.direction;
    if (joystickDirection == JoystickDirection.up &&
        groundPlatform != null &&
        !isBlocking &&
        !isAttackCommitted &&
        !isAirborne &&
        stamina >= 15) {
      velocity.y = -320; // Slightly higher jump
      groundPlatform = null;
      stamina -= 15; // Less stamina cost
      isJumping = true;
    }

    // Dodge roll - Thief has shorter cooldown
    if (joystickDelta.length > 0.5 &&
        joystickDelta.y < -0.5 &&
        groundPlatform != null &&
        !isBlocking) {
      dodge(Vector2(joystickDelta.x, 0));
    }
  }

  @override
  void updateBotControl(double dt) {
    if (botTactic != null && !isStunned && !isLanding) {
      botTactic!.execute(this, game.player, dt);
      _botAdvancedMechanics(dt);
    }
  }

  void _botAdvancedMechanics(double dt) {
    // Thief bots are more aggressive with dodging
    final nearbyProjectiles = game.projectiles.where((p) {
      return p.owner != null &&
          position.distanceTo(p.position) < 200 &&
          dodgeCooldown <= 0;
    }).toList();

    if (nearbyProjectiles.isNotEmpty && stamina > 15) {
      final projectile = nearbyProjectiles.first;
      final dodgeDir = Vector2(
          projectile.direction.x > 0 ? -1 : 1,
          0
      );
      dodge(dodgeDir);
    }
  }

  @override
  void attack() {
    if (isBlocking) return;

    // Prepare attack with common logic
    if (!prepareAttack()) return;

    // Thief-specific ranged attack - throwing knives
    // Can throw multiple knives in a combo
    final knifeCount = comboCount >= 3 ? 3 : 1; // Triple throw on high combo

    for (int i = 0; i < knifeCount; i++) {
      final spreadAngle = (i - (knifeCount - 1) / 2) * 0.2; // Spread knives
      final baseDirection = facingRight ? Vector2(1, 0) : Vector2(-1, 0);
      final direction = Vector2(baseDirection.x, baseDirection.y)..rotate(spreadAngle);

      final projectile = Projectile(
        position: position.clone(),
        direction: direction,
        damage: stats.attackDamage * (1.0 + (comboCount - 1) * 0.15),
        owner: playerType == PlayerType.human ? this as Player : null,
        enemyOwner: playerType == PlayerType.bot ? this as Enemy : null,
        color: Colors.grey,
        type: 'knife',
      );
      game.add(projectile);
      game.world.add(projectile);
      game.projectiles.add(projectile);
    }
  }
}