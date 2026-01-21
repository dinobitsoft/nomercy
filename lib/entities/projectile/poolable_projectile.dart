import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:nomercy/entities/projectile/projectile.dart';

import '../../game/game_character.dart';

/// Poolable projectile with reset capability
class PoolableProjectile extends Projectile {
  PoolableProjectile()
      : super(
    position: Vector2.zero(),
    direction: Vector2.zero(),
    damage: 0,
    color: const Color(0xFF000000),
    type: 'projectile',
  );

  /// Reset projectile state for reuse
  void reset({
    required Vector2 newPosition,
    required Vector2 newDirection,
    required double newDamage,
    required Color newColor,
    required String newType,
    GameCharacter? newOwner,
    GameCharacter? newEnemyOwner,
  }) {
    position = newPosition.clone();
    direction = newDirection.clone();
    damage = newDamage;
    color = newColor;
    type = newType;
    owner = newOwner;
    enemyOwner = newEnemyOwner;

    // Reset timers
    lifetime = 3.0;
    trailTimer = 0;
    pulseTimer = 0;
    trail.clear();
    rotation = math.atan2(direction.y, direction.x);
  }
}