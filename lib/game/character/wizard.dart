import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:nomercy/projectile/projectile.dart';

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
    botTactic: botTactic ?? DefensiveTactic(),
    stats: WizardStats(),
  );

  @override
  void updateHumanControl(double dt) {
    // Skip if stunned, landing recovery, or dodge rolling
    if (isStunned || isLanding || isDodging) return;

    final joystickDelta = game.joystick.relativeDelta;
    final moveSpeed = stats.dexterity / 2;

    // Wizard has poor mobility during attack commit
    final moveMultiplier = isAttackCommitted ? 0.2 : 1.0;

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

    // Jump - Wizard has standard jump
    final joystickDirection = game.joystick.direction;
    if (joystickDirection == JoystickDirection.up &&
        groundPlatform != null &&
        !isBlocking &&
        !isAttackCommitted &&
        !isAirborne &&
        stamina >= 20) {
      velocity.y = -280; // Lower jump height
      groundPlatform = null;
      stamina -= 20;
      isJumping = true;
    }

    // Dodge roll
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
    // Wizard prefers blocking over dodging
    final distanceToPlayer = position.distanceTo(game.player.position);
    if (distanceToPlayer < 200 &&
        game.player.isAttacking &&
        !isDodging &&
        stamina > 30) {
      startBlock();
    } else if (isBlocking && (!game.player.isAttacking || distanceToPlayer > 200)) {
      stopBlock();
    }

    // Only dodge if really necessary
    final nearbyProjectiles = game.projectiles.where((p) {
      return p.owner != null &&
          position.distanceTo(p.position) < 100 &&
          dodgeCooldown <= 0;
    }).toList();

    if (nearbyProjectiles.isNotEmpty && stamina > 20 && !isBlocking) {
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

    // Wizard-specific ranged attack - powerful fireball
    // Higher stamina cost for powerful magic
    stamina -= 5; // Extra stamina cost

    // Charged fireball on high combo
    final damageMultiplier = 1.0 + (comboCount - 1) * 0.25; // +25% per combo

    final projectile = Projectile(
      position: position.clone(),
      direction: facingRight ? Vector2(1, 0) : Vector2(-1, 0),
      damage: stats.attackDamage * damageMultiplier,
      owner: playerType == PlayerType.human ? this as Player : null,
      enemyOwner: playerType == PlayerType.bot ? this as Enemy : null,
      color: comboCount >= 3 ? Colors.blue : Colors.orange, // Blue for charged
      type: 'fireball',
    );
    game.add(projectile);
    game.world.add(projectile);
    game.projectiles.add(projectile);

    // Recoil effect - wizard gets pushed back slightly
    if (!isAirborne) {
      velocity.x -= (facingRight ? 30 : -30);
    }
  }
}