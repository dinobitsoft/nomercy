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

class Thief extends GameCharacter {
  final EventBus _eventBus = EventBus();

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
    if (isStunned || isLanding || isDodging) return;

    // Unified input: Touch + Gamepad
    final gamepad = game.gamepadManager;
    Vector2 inputDelta = game.joystick.relativeDelta;

    if (gamepad.isGamepadConnected && gamepad.hasMovementInput()) {
      inputDelta = gamepad.getJoystickDirection();
    }

    final moveSpeed = stats.dexterity / 2;
    final moveMultiplier = isAttackCommitted ? 0.5 : 1.0;

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

    // JUMP (Thief has high jump)
    bool jumpInput = (game.joystick.direction == JoystickDirection.up) ||
        gamepad.isJumpPressed;

    if (jumpInput &&
        groundPlatform != null &&
        !isBlocking &&
        !isAttackCommitted &&
        !isAirborne &&
        stamina >= 15) {
      performJump(customPower: -320);
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
    // Thief prefers dodging over blocking
    final nearbyProjectiles = game.projectiles.where((p) {
      return p.owner != null &&
          position.distanceTo(p.position) < 200 &&
          dodgeCooldown <= 0;
    }).toList();

    if (nearbyProjectiles.isNotEmpty && stamina > 15) {
      final projectile = nearbyProjectiles.first;
      final dodgeDir = Vector2(
        projectile.direction.x > 0 ? -1 : 1,
        0,
      );
      dodge(dodgeDir);
    }
  }

  @override
  void attack() {
    if (isBlocking || health <= 0) return;

    // REFACTORED: Use event-driven attack preparation
    if (!prepareAttackWithEvent()) return;

    // Throwing knives - multiple projectiles on combo
    final knifeCount = comboCount >= 3 ? 3 : 1;

    for (int i = 0; i < knifeCount; i++) {
      final spreadAngle = (i - (knifeCount - 1) / 2) * 0.2;
      final baseDirection = facingRight ? Vector2(1, 0) : Vector2(-1, 0);
      final direction = Vector2(baseDirection.x, baseDirection.y)
        ..rotate(spreadAngle);

      final projectile = Projectile(
        position: position.clone(),
        direction: direction,
        damage: stats.attackDamage * (1.0 + (comboCount - 1) * 0.15),
        owner: playerType == PlayerType.human ? this : null,
        enemyOwner: playerType == PlayerType.bot ? this : null,
        color: Colors.grey,
        type: 'knife',
      );

      game.add(projectile);
      game.world.add(projectile);
      game.projectiles.add(projectile);

      _eventBus.emit(ProjectileFiredEvent(
        shooterId: stats.name,
        projectileType: 'knife',
        position: position.clone(),
        direction: direction,
        damage: projectile.damage,
      ));
    }

    _eventBus.emit(PlaySFXEvent(soundId: 'dagger_shot', volume: 0.8));
  }

}