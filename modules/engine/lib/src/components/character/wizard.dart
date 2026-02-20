import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Wizard extends GameCharacter {
  final EventBus _eventBus = EventBus();

  @override
  double get jumpPower => -280;

  Wizard({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
    super.customId,
  }) : super(
    botTactic: botTactic ?? DefensiveTactic(),
    stats: WizardStats(),
  );

  @override
  void updateHumanControl(double dt) {
    if (characterState.isStunned || characterState.isLanding || characterState.isDodging) return;

    final gamepad = game.gamepadManager;
    Vector2 inputDelta = game.joystick.relativeDelta;

    if (gamepad.isGamepadConnected && gamepad.hasMovementInput()) {
      inputDelta = gamepad.getJoystickDirection();
    }

    final moveSpeed = stats.dexterity / 2;
    final moveMultiplier = characterState.isAttackCommitted ? 0.2 : 1.0;

    if (inputDelta.x != 0 && !characterState.isBlocking) {
      final direction = Vector2(inputDelta.x, 0);
      performWalk(direction, moveSpeed * 100 * moveMultiplier);
    } else if (!characterState.isAttackCommitted && !characterState.isBlocking) {
      performStopWalk();
    }

    bool blockInput = gamepad.isBlockPressed;
    if (blockInput && characterState.groundPlatform != null) {
      startBlock();
      velocity.x = 0;
    } else {
      stopBlock();
    }

    //JUMP
    bool jumpInput = game.joystick.direction == JoystickDirection.up || gamepad.isJumpPressed;
    if (!characterState.isBlocking && !characterState.isAttackCommitted) {
      handleJumpInput(jumpInput);
    } else {
      prevJumpInput = jumpInput;
    }

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
    final distanceToPlayer = position.distanceTo(game.character.position);
    if (distanceToPlayer < 200 && game.character.characterState.isAttacking &&
        !characterState.isDodging && characterState.stamina > 30) {
      startBlock();
    } else if (characterState.isBlocking && (!game.character.characterState.isAttacking || distanceToPlayer > 200)) {
      stopBlock();
    }

    final nearbyProjectiles = game.projectiles.where((p) {
      return p.owner != null &&
          position.distanceTo(p.position) < 100 &&
          characterState.dodgeCooldown <= 0;
    }).toList();

    if (nearbyProjectiles.isNotEmpty && characterState.stamina > 20 && !characterState.isBlocking) {
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

    if (!prepareAttackWithEvent()) return;

    characterState.stamina -= 5;

    final damageMultiplier = 1.0 + (characterState.comboCount - 1) * 0.25;
    final isPowerShot = characterState.comboCount >= 3;
    final direction = facingRight ? Vector2(1, 0) : Vector2(-1, 0);

    // CRITICAL FIX: Ensure projectile spawns at visible position
    final spawnOffset = facingRight ? Vector2(40, 0) : Vector2(-40, 0);
    final spawnPos = position + spawnOffset;

    final projectile = Projectile(
      position: spawnPos,
      direction: direction,
      damage: stats.attackDamage * damageMultiplier,
      owner: playerType == PlayerType.human ? this : null,
      enemyOwner: playerType == PlayerType.bot ? this : null,
      color: isPowerShot ? Colors.blue : Colors.orange,
      type: 'fireball',
    );

    // CRITICAL: Set correct priority
    projectile.priority = 75;

    // CRITICAL: Add in correct order
    game.add(projectile);
    game.world.add(projectile);
    game.projectiles.add(projectile);

    print('🔮 Wizard ${playerType == PlayerType.bot ? "BOT" : "PLAYER"} created fireball at ${spawnPos.x.toInt()}, ${spawnPos.y.toInt()}');

    _eventBus.emit(ProjectileFiredEvent(
      shooterId: stats.name,
      projectileType: 'fireball',
      position: spawnPos,
      direction: direction,
      damage: projectile.damage,
    ));

    if (!characterState.isAirborne) {
      velocity.x -= (facingRight ? 30 : -30);
    }

    _eventBus.emit(PlaySFXEvent(soundId: 'fireball_shot', volume: 0.8));

    if (isPowerShot) {
      print('${stats.name}: POWER FIREBALL!');
    }
  }
}

class WizardStats extends CharacterStats {
  WizardStats() : super(
    name: 'Wizard',
    power: 6,
    magic: 18,
    dexterity: 7,
    intelligence: 14,
    weaponName: 'Fireball',
    attackRange: 10.0,
    attackDamage: 20,
    color: Colors.purple,
  );
}