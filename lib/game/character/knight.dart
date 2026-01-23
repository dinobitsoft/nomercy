import 'package:flame/components.dart';

import '../../core/event_bus.dart';
import '../../core/game_event.dart';
import '../../player_type.dart';
import '../bot_tactic.dart';
import '../game_character.dart';
import '../stat/stats.dart';
import '../tactic/aggressive_tactic.dart';
class Knight extends GameCharacter {
  final EventBus _eventBus = EventBus();

  Knight({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
  }) : super(
    botTactic: botTactic ?? AggressiveTactic(),
    stats: KnightStats(),
  );

  @override
  void updateHumanControl(double dt) {
    if (isStunned || isLanding || isDodging) return;

    // ==========================================
    // UNIFIED INPUT: Touch Joystick + Gamepad
    // ==========================================
    final gamepad = game.gamepadManager;

    // Combine touch joystick and gamepad joystick
    Vector2 inputDelta = game.joystick.relativeDelta;

    // If gamepad is connected and has input, use gamepad instead
    if (gamepad.isGamepadConnected && gamepad.hasMovementInput()) {
      inputDelta = gamepad.getJoystickDirection();
    }

    final moveSpeed = stats.dexterity / 2;
    final moveMultiplier = isAttackCommitted ? 0.3 : 1.0;

    // MOVEMENT
    if (inputDelta.x != 0 && !isBlocking) {
      final direction = Vector2(inputDelta.x, 0);
      performWalk(direction, moveSpeed * 100 * moveMultiplier);
    } else if (!isAttackCommitted && !isBlocking) {
      performStopWalk();
    }

    // BLOCK (Down on joystick or Y button on gamepad)
    bool blockInput = inputDelta.y > 0.5 || gamepad.isBlockPressed;
    if (blockInput && groundPlatform != null) {
      startBlock();
      velocity.x = 0;
    } else {
      stopBlock();
    }

    // JUMP (Up on joystick or A button on gamepad)
    bool jumpInput = (game.joystick.direction == JoystickDirection.up) ||
        gamepad.isJumpPressed;

    if (jumpInput &&
        groundPlatform != null &&
        !isBlocking &&
        !isAttackCommitted &&
        !isAirborne &&
        stamina >= 20) {
      performJump(customPower: -500); // Knight has high jump
    }

    // DODGE (Diagonal down or B button on gamepad)
    bool dodgeInput = (inputDelta.length > 0.5 && inputDelta.y < -0.5) ||
        gamepad.isDodgePressed;

    if (dodgeInput &&
        groundPlatform != null &&
        !isBlocking) {
      final dodgeDirection = inputDelta.x != 0
          ? Vector2(inputDelta.x, 0)
          : Vector2(facingRight ? 1 : -1, 0);
      dodge(dodgeDirection);
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
    // Dodge incoming projectiles
    final nearbyProjectiles = game.projectiles.where((p) {
      return p.owner != null &&
          position.distanceTo(p.position) < 150 &&
          dodgeCooldown <= 0;
    }).toList();

    if (nearbyProjectiles.isNotEmpty && stamina > 20) {
      final projectile = nearbyProjectiles.first;
      final dodgeDir = Vector2(
        projectile.direction.x > 0 ? -1 : 1,
        0,
      );
      dodge(dodgeDir); // Now emits event
    }

    // Block when player attacking nearby
    final distanceToPlayer = position.distanceTo(game.player.position);
    if (distanceToPlayer < 150 &&
        game.player.isAttacking &&
        !isDodging &&
        stamina > 30) {
      startBlock(); // Now emits event
    } else if (isBlocking &&
        (!game.player.isAttacking || distanceToPlayer > 150)) {
      stopBlock(); // Now emits event
    }
  }

  @override
  void attack() {
    if (isBlocking) return;

    // REFACTORED: Use event-driven attack preparation
    if (!prepareAttackWithEvent()) return;

    // Use combat system for attack processing
    final targets = playerType == PlayerType.human ? game.enemies : [game.player];

    int targetsHit = 0;
    double totalDamage = 0;

    for (final target in targets) {
      final distance = position.distanceTo(target.position);
      final attackRange = stats.attackRange * 30 * (1 + comboCount * 0.1);

      if (distance < attackRange) {
        final toTarget = target.position.x - position.x;
        final facingTarget =
            (facingRight && toTarget > 0) || (!facingRight && toTarget < 0);

        if (facingTarget || distance < 50) {
          // Process attack through combat system
          final damage = stats.attackDamage * (1.0 + (comboCount - 1) * 0.2);
          game.combatSystem.processAttack(
            attacker: this,
            target: target,
            attackType: 'melee',
          );

          // Knockback
          final knockbackDir = facingRight ? 1 : -1;
          target.velocity.x += knockbackDir * 150;

          if (comboCount >= 3) {
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