import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Knight extends GameCharacter {
  final EventBus _eventBus = EventBus();

  Knight({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
    super.customId,
  }) : super(
    botTactic: botTactic ?? AggressiveTactic(),
    stats: KnightStats(),
  );

  @override
  double get jumpPower => -350;

  @override
  void updateHumanControl(double dt) {
    if (characterState.isStunned || characterState.isLanding || characterState.isDodging) return;

    final gamepad = game.gamepadManager;

    Vector2 inputDelta = game.joystick.relativeDelta;
    if (gamepad.isGamepadConnected && gamepad.hasMovementInput()) {
      inputDelta = gamepad.getJoystickDirection();
    }

    final moveSpeed = stats.dexterity / 2;
    final moveMultiplier = characterState.isAttackCommitted ? 0.3 : 1.0;

    // MOVEMENT
    if (inputDelta.x != 0 && !characterState.isBlocking) {
      performWalk(Vector2(inputDelta.x, 0), moveSpeed * 100 * moveMultiplier);
    } else if (!characterState.isAttackCommitted && !characterState.isBlocking) {
      performStopWalk();
    }

    // BLOCK — Y button or down-stick; use continuous press (not edge)
    final blockInput = gamepad.isBlockPressed;
    if (blockInput && characterState.groundPlatform != null) {
      startBlock();
      velocity.x = 0;
    } else {
      stopBlock();
    }

    // JUMP — edge-detected via handleJumpInput
    final jumpInput = game.joystick.direction == JoystickDirection.up ||
        gamepad.isJumpPressed;
    if (!characterState.isBlocking && !characterState.isAttackCommitted) {
      handleJumpInput(jumpInput);
    } else {
      prevJumpInput = jumpInput;
    }

    // DODGE — B button (edge-detected) OR joystick flick down+direction
    // inputDelta.y > 0.5 = stick pushed down (positive Y = down in game coords)
    final stickDodge = inputDelta.length > 0.5 && inputDelta.y > 0.5;
    final buttonDodge = gamepad.isDodgeJustPressed();

    if ((stickDodge || buttonDodge) &&
        characterState.groundPlatform != null &&
        !characterState.isBlocking &&
        characterState.dodgeCooldown <= 0) {
      final dodgeDir = inputDelta.x != 0
          ? Vector2(inputDelta.x, 0)
          : Vector2(facingRight ? 1 : -1, 0);
      dodge(dodgeDir);
    }
  }

  @override
  void updateBotControl(double dt) {
    if (botTactic != null &&
        !characterState.isStunned &&
        !characterState.isLanding &&
        characterState.health > 0) {
      botTactic!.execute(this, game.character, dt);
    }
  }

  void _botAdvancedMechanics(double dt) {
    // Dodge incoming projectiles
    final nearbyProjectiles = game.projectiles.where((p) {
      return p.owner != null &&
          position.distanceTo(p.position) < 150 &&
          characterState.dodgeCooldown <= 0;
    }).toList();

    if (nearbyProjectiles.isNotEmpty && characterState.stamina > 20) {
      final projectile = nearbyProjectiles.first;
      final dodgeDir = Vector2(
        projectile.direction.x > 0 ? -1 : 1,
        0,
      );
      dodge(dodgeDir); // Now emits event
    }

    // Block when player attacking nearby
    final distanceToPlayer = position.distanceTo(game.character.position);
    if (distanceToPlayer < 150 &&
        game.character.characterState.isAttacking &&
        !characterState.isDodging &&
        characterState.stamina > 30) {
      startBlock(); // Now emits event
    } else if (characterState.isBlocking &&
        (!game.character.characterState.isAttacking || distanceToPlayer > 150)) {
      stopBlock(); // Now emits event
    }
  }

  @override
  void attack() {
    if (characterState.isBlocking) return;

    // REFACTORED: Use event-driven attack preparation
    if (!prepareAttackWithEvent()) return;

    // Use combat system for attack processing
    final targets = playerType == PlayerType.human ? game.enemies : [game.character];

    int targetsHit = 0;
    double totalDamage = 0;

    for (final target in targets) {
      final distance = position.distanceTo(target.position);
      final attackRange = stats.attackRange * 30 * (1 + characterState.comboCount * 0.1);

      if (distance < attackRange) {
        final toTarget = target.position.x - position.x;
        final facingTarget =
            (facingRight && toTarget > 0) || (!facingRight && toTarget < 0);

        if (facingTarget || distance < 50) {
          // Process attack through combat system
          final damage = stats.attackDamage * (1.0 + (characterState.comboCount - 1) * 0.2);
          game.combatSystem.processAttack(
            attacker: this,
            target: target,
            attackType: 'melee',
          );

          // Knockback
          final knockbackDir = facingRight ? 1 : -1;
          target.velocity.x += knockbackDir * 150;

          if (characterState.comboCount >= 3) {
            target.velocity.y = -100;
          }

          targetsHit++;
          totalDamage += damage;
        }
      }
    }

    // Emit attack completed event with results
    // (This is normally done in update() but we can update it here)
    if (targetsHit > 0) {
      print('Knight hit $targetsHit targets for ${totalDamage.toInt()} damage');
    }
  }
}

class KnightStats extends CharacterStats {
  KnightStats() : super(
    name: 'Knight',
    power: 15,
    magic: 5,
    dexterity: 8,
    intelligence: 7,
    weaponName: 'Sword Slash',
    attackRange: 2.0,
    attackDamage: 15,
    color: Colors.blue,
  );
}