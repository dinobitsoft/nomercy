import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flame/components.dart';

import 'package:nomercy/platform.dart';
import 'package:nomercy/player.dart';

import 'action_game.dart';
import 'character_stats.dart';

class Enemy extends SpriteAnimationComponent with HasGameRef<ActionGame> {
  final CharacterStats stats;
  final Player player;
  final ActionGame game;
  Vector2 velocity = Vector2.zero();
  double health = 100;
  double attackCooldown = 0;
  Platform? groundPlatform;
  bool facingRight = true;
  bool spritesLoaded = false;

  Enemy({
    required Vector2 position,
    required this.stats,
    required this.player,
    required this.game,
  }) : super(position: position);

  @override
  Future<void> onLoad() async {
    size = Vector2(40, 60);
    anchor = Anchor.center;

    final characterName = stats.type.name;

    try {
      final sprite = await game.loadSprite('$characterName.png');
      animation = SpriteAnimation.spriteList([sprite], stepTime: 0.2);
      spritesLoaded = true;
    } catch (e) {
      print('Could not load sprite for enemy $characterName: $e');
      spritesLoaded = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (attackCooldown > 0) attackCooldown -= dt;

    final toPlayer = player.position - position;
    final distance = toPlayer.length;

    if (distance < 300) {
      velocity.x = toPlayer.normalized().x * (stats.dexterity / 3);
      facingRight = toPlayer.x > 0;
    } else {
      velocity.x = 0;
    }

    if (spritesLoaded && animation != null) {
      scale.x = facingRight ? 1 : -1;
    }

    if (groundPlatform == null) {
      velocity.y += 800 * dt;
      velocity.y = math.min(velocity.y, 500);
    }

    position += velocity * dt;

    groundPlatform = null;
    for (final platform in game.platforms) {
      if (_checkPlatformCollision(platform)) {
        if (velocity.y > 0 && position.y < platform.position.y) {
          position.y = platform.position.y - platform.size.y / 2 - size.y / 2;
          velocity.y = 0;
          groundPlatform = platform;
        }
      }
    }

    if (distance < stats.attackRange * 30 && attackCooldown <= 0) {
      player.takeDamage(stats.attackDamage / 2);
      attackCooldown = 2.0;
    }
  }

  bool _checkPlatformCollision(Platform platform) {
    final dx = (position.x - platform.position.x).abs();
    final dy = (position.y - platform.position.y).abs();
    return dx < (size.x + platform.size.x) / 2 &&
        dy < (size.y + platform.size.y) / 2;
  }

  void takeDamage(double damage) {
    health -= damage;
    if (health <= 0) {
      game.removeEnemy(this);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (!spritesLoaded) {
      final paint = Paint()..color = stats.color.withOpacity(0.7);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
        paint,
      );
    }

    final healthBarWidth = size.x;
    final healthPercent = health / 100;
    canvas.drawRect(
      Rect.fromLTWH(-size.x / 2, -size.y / 2 - 10, healthBarWidth, 5),
      Paint()..color = Colors.red,
    );
    canvas.drawRect(
      Rect.fromLTWH(-size.x / 2, -size.y / 2 - 10, healthBarWidth * healthPercent, 5),
      Paint()..color = Colors.green,
    );
  }
}