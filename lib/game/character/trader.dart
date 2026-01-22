import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../entities/projectile/projectile.dart';
import '../../player_type.dart';
import '../bot_tactic.dart';
import '../game_character.dart';
import '../stat/stats.dart';
import '../tactic/balanced_tactic.dart';

class Trader extends GameCharacter {
  Trader({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
  }) : super(
    botTactic: botTactic ?? BalancedTactic(),
    stats: TraderStats(),
  );

  @override
  void updateHumanControl(double dt) {
    // Skip if stunned, landing recovery, or dodge rolling
    if (isStunned || isLanding || isDodging) return;

    final joystickDelta = game.joystick.relativeDelta;
    final moveSpeed = stats.dexterity / 2;

    // Trader has balanced mobility during attack commit
    final moveMultiplier = isAttackCommitted ? 0.4 : 1.0;

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

    // Jump - Trader has balanced jump
    final joystickDirection = game.joystick.direction;
    if (joystickDirection == JoystickDirection.up &&
        groundPlatform != null &&
        !isBlocking &&
        !isAttackCommitted &&
        !isAirborne &&
        stamina >= 18) {
      velocity.y = -300;
      groundPlatform = null;
      stamina -= 18;
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
    // Trader bots use balanced approach - both dodge and block
    final distanceToPlayer = position.distanceTo(game.player.position);

    // Block when player is close and attacking
    if (distanceToPlayer < 180 &&
        game.player.isAttacking &&
        !isDodging &&
        stamina > 25) {
      startBlock();
    } else if (isBlocking && (!game.player.isAttacking || distanceToPlayer > 180)) {
      stopBlock();
    }

    // Dodge projectiles
    final nearbyProjectiles = game.projectiles.where((p) {
      return p.owner != null &&
          position.distanceTo(p.position) < 150 &&
          dodgeCooldown <= 0;
    }).toList();

    if (nearbyProjectiles.isNotEmpty && stamina > 20) {
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

    // Trader-specific ranged attack - bow & arrow
    // Arrows are fast and precise, power increases with combo
    final damageMultiplier = 1.0 + (comboCount - 1) * 0.18; // +18% per combo

    // High combo = power shot (slightly slower but more damage)
    final isPowerShot = comboCount >= 4;

    final projectile = Projectile(
      position: position.clone(),
      direction: facingRight ? Vector2(1, 0) : Vector2(-1, 0),
      damage: stats.attackDamage * damageMultiplier * (isPowerShot ? 1.5 : 1.0),
      owner: playerType == PlayerType.human ? this as Player : null,
      enemyOwner: playerType == PlayerType.bot ? this as Enemy : null,
      color: isPowerShot ? Colors.red : Colors.brown,
      type: 'arrow',
    );
    game.add(projectile);
    game.world.add(projectile);
    game.projectiles.add(projectile);

    // Drawing bow - slight backward movement for realism
    if (!isAirborne) {
      velocity.x -= (facingRight ? 20 : -20);
    }

    if (isPowerShot) {
      print('${stats.name}: Power Shot!');
    }
  }
}