import 'package:flame/components.dart';

import '../../player_type.dart';
import '../bot_tactic.dart';
import '../game_character.dart';
import '../stat/stats.dart';
import '../tactic/aggressive_tactic.dart';

class Knight extends GameCharacter {
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
    // Skip if stunned, landing recovery, or dodge rolling
    if (isStunned || isLanding || isDodging) return;

    final joystickDelta = game.joystick.relativeDelta;
    final moveSpeed = stats.dexterity / 2;

    // Reduced movement during attack commit
    final moveMultiplier = isAttackCommitted ? 0.3 : 1.0;

    if (joystickDelta.x != 0 && !isBlocking) {
      velocity.x = joystickDelta.x * moveSpeed * 100 * moveMultiplier;
      facingRight = joystickDelta.x > 0;
    } else if (!isAttackCommitted && !isBlocking) {
      velocity.x *= 0.7; // Gradual slowdown
    }

    // Block with down input when grounded
    if (joystickDelta.y > 0.5 && groundPlatform != null) {
      startBlock();
      velocity.x = 0; // Can't move while blocking
    } else {
      stopBlock();
    }

    // Jump (can't jump while blocking or during attack commit)
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
    }

    // Dodge roll with double-tap or special input
    // For now, trigger dodge when moving + crouch quickly
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

      // Bots can also use advanced mechanics
      _botAdvancedMechanics(dt);
    }
  }

  void _botAdvancedMechanics(double dt) {
    // Bot dodge logic - dodge incoming projectiles
    final nearbyProjectiles = game.projectiles.where((p) {
      return p.owner != null && // From player
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

    // Bot block logic - block when player is attacking close by
    final distanceToPlayer = position.distanceTo(game.player.position);
    if (distanceToPlayer < 150 &&
        game.player.isAttacking &&
        !isDodging &&
        stamina > 30) {
      startBlock();
    } else if (isBlocking && (!game.player.isAttacking || distanceToPlayer > 150)) {
      stopBlock();
    }
  }

  @override
  void attack() {
    // Don't attack while blocking
    if (isBlocking) return;

    // Prepare attack (handles cooldown, stamina, combo logic)
    if (!prepareAttack()) return;

    // Knight-specific melee attack with combo damage
    final damageMultiplier = 1.0 + (comboCount - 1) * 0.2; // +20% per combo
    final finalDamage = stats.attackDamage * damageMultiplier;

    // Check both player and enemies
    final targets = playerType == PlayerType.human ? game.enemies : [game.player];

    for (final target in targets) {
      final distance = position.distanceTo(target.position);

      // Melee range check - increased during combo
      final attackRange = stats.attackRange * 30 * (1 + comboCount * 0.1);

      if (distance < attackRange) {
        // Direction check - must be facing target
        final toTarget = target.position.x - position.x;
        final facingTarget = (facingRight && toTarget > 0) || (!facingRight && toTarget < 0);

        if (facingTarget || distance < 50) { // Very close = hit regardless
          target.takeDamage(finalDamage);

          // Knockback on hit
          final knockbackDir = facingRight ? 1 : -1;
          target.velocity.x += knockbackDir * 150;

          if (comboCount >= 3) {
            // Extra knockback on high combo
            target.velocity.y = -100;
          }
        }
      }
    }
  }
}