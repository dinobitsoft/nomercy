import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Trader extends GameCharacter {

  final EventBus _eventBus = EventBus();

  @override
  double get jumpPower => -300;

  Trader({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
    super.customId,
  }) : super(
    botTactic: botTactic ?? BalancedTactic(),
    stats: TraderStats(),
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
    final moveMultiplier = characterState.isAttackCommitted ? 0.4 : 1.0;

    // MOVEMENT
    if (inputDelta.x != 0 && !characterState.isBlocking) {
      final direction = Vector2(inputDelta.x, 0);
      performWalk(direction, moveSpeed * 100 * moveMultiplier);
    } else if (!characterState.isAttackCommitted && !characterState.isBlocking) {
      performStopWalk();
    }

    // BLOCK
    bool blockInput = gamepad.isBlockPressed;
    if (blockInput && characterState.groundPlatform != null) {
      startBlock();
      velocity.x = 0;
    } else {
      stopBlock();
    }

    // JUMP (Trader has balanced jump)
    bool jumpInput = game.joystick.direction == JoystickDirection.up || gamepad.isJumpPressed;
    if (!characterState.isBlocking && !characterState.isAttackCommitted) {
      handleJumpInput(jumpInput);
    } else {
      prevJumpInput = jumpInput;
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
    // Trader bots use balanced approach - both dodge and block
    final distanceToPlayer = position.distanceTo(game.character.position);

    // Block when player is close and attacking
    if (distanceToPlayer < 180 &&
        game.character.characterState.isAttacking &&
        !characterState.isDodging &&
        characterState.stamina > 25) {
      startBlock();
    } else if (characterState.isBlocking && (!game.character.characterState.isAttacking || distanceToPlayer > 180)) {
      stopBlock();
    }

    // Dodge projectiles
    final nearbyProjectiles = game.projectiles.where((p) {
      return p.owner != null &&
          position.distanceTo(p.position) < 150 &&
          characterState.dodgeCooldown <= 0;
    }).toList();

    if (nearbyProjectiles.isNotEmpty && characterState.stamina > 20) {
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
    if (characterState.isBlocking || characterState.health <= 0) return;

    // REFACTORED: Use event-driven attack preparation
    if (!prepareAttackWithEvent()) return;

    // Trader-specific ranged attack - bow & arrow
    final damageMultiplier = 1.0 + (characterState.comboCount - 1) * 0.18;
    final isPowerShot = characterState.comboCount >= 4;

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
    if (!characterState.isAirborne) {
      velocity.x -= (facingRight ? 20 : -20);
    }

    if (isPowerShot) {
      print('${stats.name}: Power Shot!');
    }

    _eventBus.emit(PlaySFXEvent(soundId: 'arrow_shot', volume: 0.8));
  }
}

class TraderStats extends CharacterStats {
  TraderStats() : super(
    name: 'Trader',
    power: 10,
    magic: 7,
    dexterity: 12,
    intelligence: 11,
    weaponName: 'Bow & Arrow',
    attackRange: 12.0,
    attackDamage: 12,
    color: Colors.orange,
  );
}