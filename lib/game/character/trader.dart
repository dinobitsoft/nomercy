import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/event_bus.dart';
import '../../core/game_event.dart';
import '../../entities/projectile/projectile.dart';
import '../../player_type.dart';
import '../bot_tactic.dart';
import '../game_character.dart';
import '../stat/stats.dart';
import '../tactic/balanced_tactic.dart';

class Trader extends GameCharacter {

  final EventBus _eventBus = EventBus();

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
    if (isStunned || isLanding || isDodging) return;

    final joystickDelta = game.joystick.relativeDelta;
    final moveSpeed = stats.dexterity / 2;
    final moveMultiplier = isAttackCommitted ? 0.4 : 1.0;

    // REFACTORED: Use event-driven walk
    if (joystickDelta.x != 0 && !isBlocking) {
      final direction = Vector2(joystickDelta.x, 0);
      performWalk(direction, moveSpeed * 100 * moveMultiplier);
    } else if (!isAttackCommitted && !isBlocking) {
      performStopWalk();
    }

    // Block with down input
    if (joystickDelta.y > 0.5 && groundPlatform != null) {
      startBlock();
      velocity.x = 0;
    } else {
      stopBlock();
    }

    // REFACTORED: Use event-driven jump (Trader has balanced jump)
    final joystickDirection = game.joystick.direction;
    if (joystickDirection == JoystickDirection.up &&
        groundPlatform != null &&
        !isBlocking &&
        !isAttackCommitted &&
        !isAirborne &&
        stamina >= 18) {
      performJump(customPower: -300); // Trader has balanced jump
    }

    // REFACTORED: Use event-driven dodge
    if (joystickDelta.length > 0.5 &&
        joystickDelta.y < -0.5 &&
        groundPlatform != null &&
        !isBlocking) {
      dodge(Vector2(joystickDelta.x, 0));
    }
  }

  @override
  void updateBotControl(double dt) {
    if (botTactic != null && !isStunned && !isLanding && health > 0) {
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
    if (isBlocking || health <= 0) return;

    // REFACTORED: Use event-driven attack preparation
    if (!prepareAttackWithEvent()) return;

    // Trader-specific ranged attack - bow & arrow
    final damageMultiplier = 1.0 + (comboCount - 1) * 0.18;
    final isPowerShot = comboCount >= 4;

    final direction = facingRight ? Vector2(1, 0) : Vector2(-1, 0);

    final projectile = Projectile(
      position: position.clone(),
      direction: direction,
      damage: stats.attackDamage * damageMultiplier * (isPowerShot ? 1.5 : 1.0),
      owner: playerType == PlayerType.human ? this as Player : null,
      enemyOwner: playerType == PlayerType.bot ? this as Enemy : null,
      color: isPowerShot ? Colors.red : Colors.brown,
      type: 'arrow',
    );
    game.add(projectile);
    game.world.add(projectile);
    game.projectiles.add(projectile);

    _eventBus.emit(ProjectileFiredEvent(
      shooterId: stats.name,
      projectileType: 'arrow',
      position: position.clone(),
      direction: direction,
      damage: projectile.damage,
    ));

    // Drawing bow - slight backward movement
    if (!isAirborne) {
      velocity.x -= (facingRight ? 20 : -20);
    }

    if (isPowerShot) {
      print('${stats.name}: Power Shot!');
    }

    _eventBus.emit(PlaySFXEvent(soundId: 'arrow_shot', volume: 0.8));
  }
}