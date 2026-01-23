import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/event_bus.dart';
import '../../core/game_event.dart';
import '../../entities/projectile/projectile.dart';
import '../../player_type.dart';
import '../bot_tactic.dart';
import '../game_character.dart';
import '../stat/stats.dart';
import '../tactic/defensive_tactic.dart';
class Wizard extends GameCharacter {

  final EventBus _eventBus = EventBus();

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
    if (isStunned || isLanding || isDodging) return;

    // Unified input: Touch + Gamepad
    final gamepad = game.gamepadManager;
    Vector2 inputDelta = game.joystick.relativeDelta;

    if (gamepad.isGamepadConnected && gamepad.hasMovementInput()) {
      inputDelta = gamepad.getJoystickDirection();
    }

    final moveSpeed = stats.dexterity / 2;
    final moveMultiplier = isAttackCommitted ? 0.2 : 1.0;

    // MOVEMENT
    if (inputDelta.x != 0 && !isBlocking) {
      final direction = Vector2(inputDelta.x, 0);
      performWalk(direction, moveSpeed * 100 * moveMultiplier);
    } else if (!isAttackCommitted && !isBlocking) {
      performStopWalk();
    }

    // BLOCK
    bool blockInput = inputDelta.y > 0.5 || gamepad.isBlockPressed;
    if (blockInput && groundPlatform != null) {
      startBlock();
      velocity.x = 0;
    } else {
      stopBlock();
    }

    // JUMP (Wizard has lower jump)
    bool jumpInput = (game.joystick.direction == JoystickDirection.up) ||
        gamepad.isJumpPressed;

    if (jumpInput &&
        groundPlatform != null &&
        !isBlocking &&
        !isAttackCommitted &&
        !isAirborne &&
        stamina >= 20) {
      performJump(customPower: -280);
    }

    // DODGE
    bool dodgeInput = (inputDelta.length > 0.5 && inputDelta.y < -0.5) ||
        gamepad.isDodgePressed;

    if (dodgeInput && groundPlatform != null && !isBlocking) {
      final dodgeDirection = inputDelta.x != 0
          ? Vector2(inputDelta.x, 0)
          : Vector2(facingRight ? 1 : -1, 0);
      dodge(dodgeDirection);
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
    if (isBlocking || health <= 0) return;

    // REFACTORED: Use event-driven attack preparation
    if (!prepareAttackWithEvent()) return;

    // Extra stamina cost for powerful magic
    stamina -= 5;

    // Charged fireball on high combo
    final damageMultiplier = 1.0 + (comboCount - 1) * 0.25;

    final direction = facingRight ? Vector2(1, 0) : Vector2(-1, 0);

    final projectile = Projectile(
      position: position.clone(),
      direction: direction,
      damage: stats.attackDamage * damageMultiplier,
      owner: playerType == PlayerType.human ? this as Player : null,
      enemyOwner: playerType == PlayerType.bot ? this as Enemy : null,
      color: comboCount >= 3 ? Colors.blue : Colors.orange,
      type: 'fireball',
    );
    game.add(projectile);
    game.world.add(projectile);
    game.projectiles.add(projectile);

    _eventBus.emit(ProjectileFiredEvent(
      shooterId: stats.name,
      projectileType: 'fireball',
      position: position.clone(),
      direction: direction,
      damage: projectile.damage,
    ));

    // Recoil effect
    if (!isAirborne) {
      velocity.x -= (facingRight ? 30 : -30);
    }

    _eventBus.emit(PlaySFXEvent(soundId: 'fireball_shot', volume: 0.8));
  }
}