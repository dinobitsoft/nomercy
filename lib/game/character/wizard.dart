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
// lib/game/character/wizard.dart - FIXED VERSION

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
    super.customId,
  }) : super(
    botTactic: botTactic ?? DefensiveTactic(),
    stats: WizardStats(),
  );

  @override
  void updateHumanControl(double dt) {
    if (isStunned || isLanding || isDodging) return;

    final gamepad = game.gamepadManager;
    Vector2 inputDelta = game.joystick.relativeDelta;

    if (gamepad.isGamepadConnected && gamepad.hasMovementInput()) {
      inputDelta = gamepad.getJoystickDirection();
    }

    final moveSpeed = stats.dexterity / 2;
    final moveMultiplier = isAttackCommitted ? 0.2 : 1.0;

    if (inputDelta.x != 0 && !isBlocking) {
      final direction = Vector2(inputDelta.x, 0);
      performWalk(direction, moveSpeed * 100 * moveMultiplier);
    } else if (!isAttackCommitted && !isBlocking) {
      performStopWalk();
    }

    bool blockInput = inputDelta.y > 0.5 || gamepad.isBlockPressed;
    if (blockInput && groundPlatform != null) {
      startBlock();
      velocity.x = 0;
    } else {
      stopBlock();
    }

    bool jumpInput = (game.joystick.direction == JoystickDirection.up) ||
        gamepad.isJumpPressed;

    if (jumpInput && groundPlatform != null && !isBlocking &&
        !isAttackCommitted && !isAirborne && stamina >= 20) {
      performJump(customPower: -280);
    }

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
    final distanceToPlayer = position.distanceTo(game.player.position);
    if (distanceToPlayer < 200 && game.player.isAttacking &&
        !isDodging && stamina > 30) {
      startBlock();
    } else if (isBlocking && (!game.player.isAttacking || distanceToPlayer > 200)) {
      stopBlock();
    }

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

    if (!prepareAttackWithEvent()) return;

    stamina -= 5;

    final damageMultiplier = 1.0 + (comboCount - 1) * 0.25;
    final isPowerShot = comboCount >= 3;
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

    if (!isAirborne) {
      velocity.x -= (facingRight ? 30 : -30);
    }

    _eventBus.emit(PlaySFXEvent(soundId: 'fireball_shot', volume: 0.8));

    if (isPowerShot) {
      print('${stats.name}: POWER FIREBALL!');
    }
  }
}