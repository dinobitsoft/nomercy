import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math' as math;

import '../action_game.dart';
import '../character_stats.dart';
import '../player_type.dart';
import '../tiled_platform.dart';
import 'bot_tactic.dart';

typedef Player = GameCharacter;
typedef Enemy = GameCharacter;

abstract class GameCharacter extends SpriteAnimationComponent with HasGameRef<ActionGame> {
  final CharacterStats stats;
  final PlayerType playerType;
  BotTactic? botTactic;

  // Character dimensions
  static const double baseWidth = 160.0;
  static const double baseHeight = 240.0;

  // Physics
  Vector2 velocity = Vector2.zero();
  TiledPlatform? groundPlatform;
  bool facingRight = true;

  // State
  double health = 100;
  bool isCrouching = false;
  bool isClimbing = false;
  bool isWallSliding = false;
  bool isJumping = false;
  double attackCooldown = 0;

  // Animation
  SpriteAnimation? idleAnimation;
  SpriteAnimation? walkAnimation;
  SpriteAnimation? attackAnimation;
  bool isAttacking = false;
  double attackAnimationTimer = 0;
  bool spritesLoaded = false;

  GameCharacter({
    required Vector2 position,
    required this.stats,
    required this.playerType,
    this.botTactic,
  }) : super(position: position) {
    size = Vector2(baseWidth, baseHeight);
    anchor = Anchor.center;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadSprites();
  }

  Future<void> _loadSprites() async {
    final characterName = stats.name.toLowerCase();

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
      }
    }

    if (health <= 0) {
      if (playerType == PlayerType.bot) {
        game.removeEnemy(this);
      } else {
        game.gameOver();
      }
      return;
    }

    // Update based on type
    if (playerType == PlayerType.human) {
      updateHumanControl(dt);
    } else {
      updateBotControl(dt);
    }

    applyPhysics(dt);
    updateAnimation();

    size.y = isCrouching ? baseHeight / 2 : baseHeight;
  }

  void updateHumanControl(double dt);
  void updateBotControl(double dt);
  void attack();

  void applyPhysics(double dt) {
    if (groundPlatform == null && !isClimbing) {
      velocity.y += 1000 * dt;
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
          isJumping = false;
        }
      }
    }
  }

  bool _checkPlatformCollision(TiledPlatform platform) {
    final dx = (position.x - platform.position.x).abs();
    final dy = (position.y - platform.position.y).abs();
    return dx < (size.x + platform.size.x) / 2 &&
        dy < (size.y + platform.size.y) / 2;
  }

  void updateAnimation() {
    if (!spritesLoaded) return;

    if (isAttacking && attackAnimation != null) {
      animation = attackAnimation;
    } else {
      if (velocity.x.abs() > 10) {
        animation = walkAnimation;
      } else {
        animation = idleAnimation;
      }
    }

    scale.x = facingRight ? 1 : -1;
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
    }

    // Health bar for bots
    if (playerType == PlayerType.bot) {
      final healthBarWidth = size.x;
      final healthPercent = (health / 100).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, -size.y / 2 - 20, healthBarWidth, 10),
        Paint()..color = Colors.red,
      );
      canvas.drawRect(
        Rect.fromLTWH(-size.x / 2, -size.y / 2 - 20, healthBarWidth * healthPercent, 10),
        Paint()..color = Colors.green,
      );
    }
  }
}
