import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Thief extends GameCharacter {
  final EventBus _eventBus = EventBus();

  Thief({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
    super.customId,
  }) : super(
    botTactic: botTactic ?? BalancedTactic(),
    stats: ThiefStats(),
  );

  @override
  void updateHumanControl(double dt) {
    if (characterState.isStunned || characterState.isLanding || characterState.isDodging) return;

    // Unified input: Touch + Gamepad
    final gamepad = game.gamepadManager;
    Vector2 inputDelta = game.joystick.relativeDelta;

    if (gamepad.isGamepadConnected && gamepad.hasMovementInput()) {
      inputDelta = gamepad.getJoystickDirection();
    }

    final moveSpeed = stats.dexterity / 2;
    final moveMultiplier = characterState.isAttackCommitted ? 0.5 : 1.0;

    // MOVEMENT
    if (inputDelta.x != 0 && !characterState.isBlocking) {
      final direction = Vector2(inputDelta.x, 0);
      performWalk(direction, moveSpeed * 100 * moveMultiplier);
    } else if (!characterState.isAttackCommitted && !characterState.isBlocking) {
      performStopWalk();
    }

    // BLOCK
    bool blockInput = inputDelta.y > 0.5 || gamepad.isBlockPressed;
    if (blockInput && characterState.groundPlatform != null) {
      startBlock();
      velocity.x = 0;
    } else {
      stopBlock();
    }

    // JUMP (Thief has high jump)
    bool jumpInput = (game.joystick.direction == JoystickDirection.up) ||
        gamepad.isJumpPressed;

    if (jumpInput &&
        characterState.groundPlatform != null &&
        !characterState.isBlocking &&
        !characterState.isAttackCommitted &&
        !characterState.isAirborne &&
        characterState.stamina >= 15) {
      performJump(customPower: -320);
    }

    // DODGE
    bool dodgeInput = (inputDelta.length > 0.5 && inputDelta.y < -0.5) ||
        gamepad.isDodgePressed;

    if (dodgeInput && characterState.groundPlatform != null && !characterState.isBlocking) {
      final dodgeDirection = inputDelta.x != 0
          ? Vector2(inputDelta.x, 0)
          : Vector2(facingRight ? 1 : -1, 0);
      dodge(dodgeDirection);
    }
  }

  @override
  void updateBotControl(double dt) {
    if (botTactic != null && !characterState.isStunned && !characterState.isLanding && characterState.health > 0) {
      botTactic!.execute(this, game.character, dt);
      _botAdvancedMechanics(dt);
    }
  }

  void _botAdvancedMechanics(double dt) {
    // Thief prefers dodging over blocking
    final nearbyProjectiles = game.projectiles.where((p) {
      return p.owner != null &&
          position.distanceTo(p.position) < 200 &&
          characterState.dodgeCooldown <= 0;
    }).toList();

    if (nearbyProjectiles.isNotEmpty && characterState.stamina > 15) {
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
    if (characterState.isBlocking || characterState.health <= 0) return;

    // REFACTORED: Use event-driven attack preparation
    if (!prepareAttackWithEvent()) return;

    // Throwing knives - multiple projectiles on combo
    final knifeCount = characterState.comboCount >= 3 ? 3 : 1;

    for (int i = 0; i < knifeCount; i++) {
      final spreadAngle = (i - (knifeCount - 1) / 2) * 0.2;
      final baseDirection = facingRight ? Vector2(1, 0) : Vector2(-1, 0);
      final direction = Vector2(baseDirection.x, baseDirection.y)
        ..rotate(spreadAngle);

      final projectile = Projectile(
        position: position.clone(),
        direction: direction,
        damage: stats.attackDamage * (1.0 + (characterState.comboCount - 1) * 0.15),
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

class ThiefStats extends CharacterStats {
  ThiefStats() : super(
    name: 'Thief',
    power: 8,
    magic: 6,
    dexterity: 16,
    intelligence: 10,
    weaponName: 'Throwing Knives',
    attackRange: 8.0,
    attackDamage: 10,
    color: Colors.green,
  );
}