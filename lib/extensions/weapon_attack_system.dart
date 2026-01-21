// Add this method to GameCharacter class to use equipped weapons

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import '../action_game.dart';
import '../entities/projectile/projectile.dart';
import '../game/game_character.dart';
import '../player_type.dart';
import '../item/item.dart';

extension WeaponAttackSystem on GameCharacter {

  /// Enhanced attack that uses equipped weapon properties
  void attackWithWeapon() {
    if (isBlocking) return;

    // Prepare attack with common logic
    if (!prepareAttack()) return;

    // Get equipped weapon from game
    final equippedWeapon = game.equippedWeapon;

    if (equippedWeapon == null) {
      // Use default character attack
      attack();
      return;
    }

    // Apply weapon-specific attack cooldown
    attackCooldown *= equippedWeapon.attackSpeed;

    // Weapon-based attack logic
    if (equippedWeapon.weaponType == WeaponType.sword ||
        equippedWeapon.weaponType == WeaponType.axe) {
      // Melee weapons
      _performMeleeAttack(equippedWeapon);
    } else {
      // Ranged weapons (bow, staff, dagger, crossbow)
      _performRangedAttack(equippedWeapon);
    }
  }

  void _performMeleeAttack(Weapon weapon) {
    final damageMultiplier = 1.0 + (comboCount - 1) * 0.2;
    final finalDamage = weapon.damage * damageMultiplier;

    // Check targets
    final targets = playerType == PlayerType.human ? game.enemies : [game.player];

    for (final target in targets) {
      final distance = position.distanceTo(target.position);
      final attackRange = weapon.range * 30 * (1 + comboCount * 0.1);

      if (distance < attackRange) {
        final toTarget = target.position.x - position.x;
        final facingTarget = (facingRight && toTarget > 0) || (!facingRight && toTarget < 0);

        if (facingTarget || distance < 50) {
          target.takeDamage(finalDamage);

          // Knockback based on weapon type
          final knockbackDir = facingRight ? 1 : -1;
          final knockbackPower = weapon.weaponType == WeaponType.axe ? 200 : 150;
          target.velocity.x += knockbackDir * knockbackPower;

          if (comboCount >= 3) {
            target.velocity.y = -100;
          }

          // Visual effect for melee
          _createMeleeSlashEffect();
        }
      }
    }
  }

  void _performRangedAttack(Weapon weapon) {
    final damageMultiplier = 1.0 + (comboCount - 1) * 0.18;
    final finalDamage = weapon.damage * damageMultiplier;

    // Special effects for high combos
    final isPowerShot = comboCount >= 3;
    final projectileCount = _getProjectileCount(weapon, isPowerShot);

    for (int i = 0; i < projectileCount; i++) {
      final spreadAngle = (i - (projectileCount - 1) / 2) * 0.15;
      final baseDirection = facingRight ? Vector2(1, 0) : Vector2(-1, 0);
      final direction = Vector2(baseDirection.x, baseDirection.y)..rotate(spreadAngle);

      final projectile = Projectile(
        position: position.clone(),
        direction: direction,
        damage: finalDamage * (isPowerShot ? 1.5 : 1.0),
        owner: playerType == PlayerType.human ? this : null,
        enemyOwner: playerType == PlayerType.bot ? this : null,
        color: _getProjectileColor(weapon, isPowerShot),
        type: weapon.projectileType,
      );

      game.add(projectile);
      game.world.add(projectile);
      game.projectiles.add(projectile);
    }

    // Recoil effect
    if (!isAirborne) {
      final recoilPower = weapon.weaponType == WeaponType.crossbow ? 40 : 20;
      velocity.x -= (facingRight ? recoilPower : -recoilPower);
    }

    if (isPowerShot) {
      print('${stats.name}: Power Shot with ${weapon.name}!');
    }
  }

  int _getProjectileCount(Weapon weapon, bool isPowerShot) {
    // Daggers throw multiple knives
    if (weapon.weaponType == WeaponType.dagger) {
      return isPowerShot ? 5 : 3;
    }
    // Crossbow fires single powerful bolt
    if (weapon.weaponType == WeaponType.crossbow) {
      return 1;
    }
    // Bow and staff fire 1-2 projectiles
    return isPowerShot ? 2 : 1;
  }

  Color _getProjectileColor(Weapon weapon, bool isPowerShot) {
    if (isPowerShot) {
      // Power shots get special colors
      switch (weapon.weaponType) {
        case WeaponType.bow:
          return Colors.red;
        case WeaponType.staff:
          return Colors.blue;
        case WeaponType.dagger:
          return Colors.purple;
        case WeaponType.crossbow:
          return Colors.yellow;
        default:
          return weapon.projectileColor;
      }
    }
    return weapon.projectileColor;
  }

  void _createMeleeSlashEffect() {
    // Create visual slash effect for melee attacks
    final slashEffect = _MeleeSlashEffect(
      position: position.clone(),
      facingRight: facingRight,
      color: game.equippedWeapon?.projectileColor ?? Colors.white,
    );
    game.add(slashEffect);
  }
}

// Melee slash visual effect
class _MeleeSlashEffect extends PositionComponent {
  final bool facingRight;
  final Color color;
  double lifetime = 0.2;
  double rotation = 0;

  _MeleeSlashEffect({
    required Vector2 position,
    required this.facingRight,
    required this.color,
  }) : super(position: position) {
    size = Vector2(80, 80);
    anchor = Anchor.center;
    rotation = facingRight ? -0.5 : 0.5;
  }

  @override
  void update(double dt) {
    super.update(dt);
    lifetime -= dt;
    rotation += (facingRight ? 5 : -5) * dt;

    if (lifetime <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final opacity = lifetime / 0.2;
    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Draw arc slash
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 40),
      rotation,
      2.0,
      false,
      paint,
    );
  }
}

// Helper class for weapon switching notifications
class WeaponNotification extends PositionComponent {
  final String weaponName;
  double lifetime = 2.0;
  double opacity = 1.0;

  WeaponNotification({
    required this.weaponName,
    required Vector2 position,
  }) : super(position: position);

  @override
  void update(double dt) {
    super.update(dt);
    position.y -= 30 * dt;
    lifetime -= dt;
    opacity = lifetime / 2.0;

    if (lifetime <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '⚔️ $weaponName Equipped!',
        style: TextStyle(
          color: Colors.orange.withOpacity(opacity),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(opacity),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2),
    );
  }
}

/// Extension to show weapon equip notification
extension WeaponNotifications on ActionGame {
  void showWeaponEquipped(String weaponName) {
    final notification = WeaponNotification(
      weaponName: weaponName,
      position: player.position.clone() + Vector2(0, -100),
    );
    add(notification);
  }
}