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

    final joystickDelta = game.joystick.relativeDelta;
    final moveSpeed = stats.dexterity / 2;
    final moveMultiplier = isAttackCommitted ? 0.3 : 1.0;

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

    // Jump
    final joystickDirection = game.joystick.direction;
    if (joystickDirection == JoystickDirection.up &&
        groundPlatform != null &&
        !isBlocking &&
        !isAttackCommitted &&
        !isAirborne &&
        stamina >= 20) {
      velocity.y = -500;
      groundPlatform = null;
      stamina -= 20;
      isJumping = true;

      _eventBus.emit(PlaySFXEvent(soundId: 'jump', volume: 0.7));
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
      dodge(dodgeDir);
    }

    // Block when player attacking nearby
    final distanceToPlayer = position.distanceTo(game.player.position);
    if (distanceToPlayer < 150 &&
        game.player.isAttacking &&
        !isDodging &&
        stamina > 30) {
      startBlock();
    } else if (isBlocking &&
        (!game.player.isAttacking || distanceToPlayer > 150)) {
      stopBlock();
    }
  }

  @override
  void attack() {
    if (isBlocking) return;
    if (!prepareAttack()) return;

    // Use combat system for attack processing
    final targets = playerType == PlayerType.human ? game.enemies : [game.player];

    for (final target in targets) {
      final distance = position.distanceTo(target.position);
      final attackRange = stats.attackRange * 30 * (1 + comboCount * 0.1);

      if (distance < attackRange) {
        final toTarget = target.position.x - position.x;
        final facingTarget =
            (facingRight && toTarget > 0) || (!facingRight && toTarget < 0);

        if (facingTarget || distance < 50) {
          // Process attack through combat system
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
        }
      }
    }
  }
}
