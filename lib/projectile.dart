import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:nomercy/player.dart';

import 'action_game.dart';

class Projectile extends PositionComponent with HasGameRef<ActionGame> {
  final Vector2 direction;
  final double damage;
  final Player owner;
  final Color color;
  double lifetime = 3.0;

  Projectile({
    required super.position,
    required this.direction,
    required this.damage,
    required this.owner,
    required this.color,
  }) {
    size = Vector2(10, 10);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);

    position += direction * 300 * dt;
    lifetime -= dt;

    for (final enemy in game.enemies) {
      if (position.distanceTo(enemy.position) < 30) {
        enemy.takeDamage(damage);
        removeFromParent();
        game.projectiles.remove(this);
        return;
      }
    }

    for (final platform in game.platforms) {
      final dx = (position.x - platform.position.x).abs();
      final dy = (position.y - platform.position.y).abs();
      if (dx < (size.x + platform.size.x) / 2 &&
          dy < (size.y + platform.size.y) / 2) {
        removeFromParent();
        game.projectiles.remove(this);
        return;
      }
    }

    if (lifetime <= 0) {
      removeFromParent();
      game.projectiles.remove(this);
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset.zero, 5, paint);
  }
}