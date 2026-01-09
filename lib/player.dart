import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:nomercy/projectile.dart';
import 'package:nomercy/tiled_platform.dart';

import 'action_game.dart';
import 'character_class.dart';
import 'character_stats.dart';

class Player extends SpriteAnimationComponent with HasGameRef<ActionGame> {
  final CharacterStats stats;
  @override
  final ActionGame game;
  Vector2 velocity = Vector2.zero();
  double health = 100;
  bool isCrouching = false;
  bool isClimbing = false;
  bool isWallSliding = false;
  double attackCooldown = 0;
  bool facingRight = true;
  TiledPlatform? groundPlatform;
  TiledPlatform? climbingWall;
  SpriteAnimation? idleAnimation;
  SpriteAnimation? walkAnimation;
  SpriteAnimation? attackAnimation;
  bool isAttacking = false;
  double attackAnimationTimer = 0;
  bool spritesLoaded = false;

  // Base size is 40x60, we multiply by 4 to make them bigger
  static final Vector2 baseSize = Vector2(128, 192);

  Player({required Vector2 position, required this.stats, required this.game})
      : super(position: position);

  @override
  Future<void> onLoad() async {
    size = baseSize.clone();
    anchor = Anchor.center;

    final characterName = stats.type.name;

    try {
      final sprite = await game.loadSprite('$characterName.png');
      idleAnimation = SpriteAnimation.spriteList([sprite], stepTime: 1.0);
      walkAnimation = SpriteAnimation.spriteList([sprite], stepTime: 0.2);

      try {
        final attackSprite = await game.loadSprite('${characterName}_attack.png');
        attackAnimation = SpriteAnimation.spriteList([attackSprite, sprite], stepTime: 0.1);
      } catch (e) {
        attackAnimation = idleAnimation;
      }

      animation = idleAnimation;
      spritesLoaded = true;
    } catch (e) {
      print('Could not load sprite for $characterName: $e');
      spritesLoaded = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (attackCooldown > 0) attackCooldown -= dt;

    if (attackAnimationTimer > 0) {
      attackAnimationTimer -= dt;
      if (attackAnimationTimer <= 0) {
        isAttacking = false;
        if (spritesLoaded && idleAnimation != null) animation = idleAnimation;
      }
    }

    final joystickDelta = game.joystick.relativeDelta;
    final joystickDirection = game.joystick.direction;
    final moveSpeed = stats.dexterity / 2;

    if (joystickDelta.x != 0) {
      velocity.x = joystickDelta.x * moveSpeed * 100;
      facingRight = joystickDelta.x > 0;

      if (!isAttacking && spritesLoaded && walkAnimation != null) {
        animation = walkAnimation;
      }
    } else {
      velocity.x = 0;

      if (!isAttacking && spritesLoaded && idleAnimation != null) {
        animation = idleAnimation;
      }
    }

    if (spritesLoaded && animation != null) {
      scale.x = facingRight ? 1 : -1;
    }

    isCrouching = joystickDirection == JoystickDirection.down && groundPlatform != null;

    isWallSliding = false;
    climbingWall = null;
    for (final platform in game.platforms) {
      if (platform.size.y > 100 && _isNearWall(platform)) {
        isWallSliding = true;
        climbingWall = platform;
        velocity.y = math.min(velocity.y, 50);
        break;
      }
    }

    if (isWallSliding && joystickDirection == JoystickDirection.up) {
      isClimbing = true;
      velocity.y = -moveSpeed * 3;
    } else {
      isClimbing = false;
    }

    if (joystickDirection == JoystickDirection.up && groundPlatform != null && !isCrouching) {
      velocity.y = -400; // Increased jump slightly for larger character
      groundPlatform = null;
    }

    if (groundPlatform == null && !isClimbing) {
      velocity.y += 1000 * dt; // Slightly more gravity for weight feel
      velocity.y = math.min(velocity.y, 600);
    }

    position += velocity * dt;

    groundPlatform = null;
    for (final platform in game.platforms) {
      if (_checkPlatformCollision(platform)) {
        if (velocity.y > 0 && position.y < platform.position.y) {
          position.y = platform.position.y - platform.size.y / 2 - size.y / 2;
          velocity.y = 0;
          groundPlatform = platform;
        } else if (velocity.y < 0 && position.y > platform.position.y) {
          position.y = platform.position.y + platform.size.y / 2 + size.y / 2;
          velocity.y = 0;
        }

        if ((position.x < platform.position.x && velocity.x > 0) ||
            (position.x > platform.position.x && velocity.x < 0)) {
          velocity.x = 0;
          if (position.x < platform.position.x) {
            position.x = platform.position.x - platform.size.x / 2 - size.x / 2;
          } else {
            position.x = platform.position.x + platform.size.x / 2 + size.x / 2;
          }
        }
      }
    }

    // Dynamic sizing for crouching (halves the height)
    size.y = isCrouching ? baseSize.y / 2 : baseSize.y;

    if (health <= 0) {
      game.gameOver();
    }
  }

  bool _checkPlatformCollision(TiledPlatform platform) {
    final dx = (position.x - platform.position.x).abs();
    final dy = (position.y - platform.position.y).abs();
    return dx < (size.x + platform.size.x) / 2 &&
        dy < (size.y + platform.size.y) / 2;
  }

  bool _isNearWall(TiledPlatform wall) {
    final dx = (position.x - wall.position.x).abs();
    final dy = (position.y - wall.position.y).abs();
    return dx < (size.x + wall.size.x) / 2 + 10 && // Adjusted for size
        dy < (size.y + wall.size.y) / 2;
  }

  void attack() {
    if (attackCooldown > 0) return;
    attackCooldown = 0.5;

    isAttacking = true;
    attackAnimationTimer = 0.2;
    if (spritesLoaded && attackAnimation != null) {
      animation = attackAnimation;
    }

    if (stats.type == CharacterClass.knight) {
      // Melee attack - no change
      for (final enemy in game.enemies) {
        if (position.distanceTo(enemy.position) < stats.attackRange * 30) {
          enemy.takeDamage(stats.attackDamage);
        }
      }
    } else {
      // NEW: Visual projectiles for ranged attacks
      String projectileType;
      Color projectileColor;

      switch (stats.type) {
        case CharacterClass.thief:
          projectileType = 'knife';
          projectileColor = Colors.grey;
          break;
        case CharacterClass.wizard:
          projectileType = 'fireball';
          projectileColor = Colors.orange;
          break;
        case CharacterClass.trader:
          projectileType = 'arrow';
          projectileColor = Colors.brown;
          break;
        default:
          projectileType = 'projectile';
          projectileColor = stats.color;
      }

      final projectile = Projectile(
        position: position.clone(),
        direction: facingRight ? Vector2(1, 0) : Vector2(-1, 0),
        damage: stats.attackDamage,
        owner: this,
        color: projectileColor,
        type: projectileType,
      );
      game.world.add(projectile);
      game.projectiles.add(projectile);
    }
  }

  void takeDamage(double damage) {
    health = math.max(0, health - damage);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (!spritesLoaded) {
      final paint = Paint()..color = stats.color;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
        paint,
      );

      final weaponPaint = Paint()..color = Colors.yellow;
      final weaponOffset = facingRight ? Offset(size.x / 2 + 10, 0) : Offset(-size.x / 2 - 10, 0);
      canvas.drawCircle(weaponOffset, 15, weaponPaint); // Larger placeholder
    }
  }
}
