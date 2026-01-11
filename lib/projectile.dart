import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'action_game.dart';
import 'game/game_character.dart';
import 'impact_effect.dart';

class Projectile extends PositionComponent with HasGameRef<ActionGame> {
  final Vector2 direction;
  final double damage;
  final GameCharacter? owner;  // null if from enemy
  final GameCharacter? enemyOwner;  // null if from player
  final Color color;
  final String type;  // 'knife', 'fireball', 'arrow'
  double lifetime = 3.0;
  final List<Vector2> trail = [];
  double trailTimer = 0;
  double rotation = 0;
  double pulseTimer = 0;

  Projectile({
    required super.position,
    required this.direction,
    required this.damage,
    this.owner,
    this.enemyOwner,
    required this.color,
    this.type = 'projectile',
  }) {
    size = Vector2(20, 20);
    anchor = Anchor.center;

    // Calculate rotation based on direction
    rotation = math.atan2(direction.y, direction.x);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Move projectile
    position += direction * 400 * dt;
    lifetime -= dt;
    pulseTimer += dt;
    trailTimer += dt;

    // Add trail point
    if (trailTimer > 0.05) {
      trail.add(position.clone());
      trailTimer = 0;

      // Limit trail length
      if (trail.length > 8) {
        trail.removeAt(0);
      }
    }

    // Check collision with player (if from enemy)
    if (enemyOwner != null) {
      if (position.distanceTo(game.player.position) < 30) {
        game.player.takeDamage(damage);
        _createImpactEffect();
        removeFromParent();
        game.projectiles.remove(this);
        return;
      }
    }

    // Check collision with enemies (if from player)
    if (owner != null) {
      for (final enemy in game.enemies) {
        if (position.distanceTo(enemy.position) < 30) {
          enemy.takeDamage(damage);
          _createImpactEffect();
          removeFromParent();
          game.projectiles.remove(this);
          return;
        }
      }
    }

    // Check platform collisions
    for (final platform in game.platforms) {
      final dx = (position.x - platform.position.x).abs();
      final dy = (position.y - platform.position.y).abs();
      if (dx < (size.x + platform.size.x) / 2 &&
          dy < (size.y + platform.size.y) / 2) {
        _createImpactEffect();
        removeFromParent();
        game.projectiles.remove(this);
        return;
      }
    }

    // Remove if lifetime expired
    if (lifetime <= 0) {
      removeFromParent();
      game.projectiles.remove(this);
    }
  }

  @override
  void render(Canvas canvas) {
    // Draw trail
    _renderTrail(canvas);

    // Draw projectile based on type
    switch (type) {
      case 'fireball':
        _renderFireball(canvas);
        break;
      case 'knife':
        _renderKnife(canvas);
        break;
      case 'arrow':
        _renderArrow(canvas);
        break;
      default:
        _renderDefault(canvas);
    }
  }

  void _renderTrail(Canvas canvas) {
    if (trail.length < 2) return;

    for (int i = 0; i < trail.length - 1; i++) {
      final opacity = (i / trail.length) * 0.5;
      final trailColor = color.withOpacity(opacity);

      final p1 = trail[i] - position;
      final p2 = trail[i + 1] - position;

      final paint = Paint()
        ..color = trailColor
        ..strokeWidth = 4 - (i / trail.length) * 2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(p1.x, p1.y),
        Offset(p2.x, p2.y),
        paint,
      );
    }
  }

  void _renderFireball(Canvas canvas) {
    // Outer glow
    final glowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, 15, glowPaint);

    // Pulsing effect
    final pulseScale = 1.0 + math.sin(pulseTimer * 10) * 0.2;

    // Main fireball
    final gradient = RadialGradient(
      colors: [
        Colors.yellow,
        Colors.orange,
        Colors.red.withOpacity(0.8),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final rect = Rect.fromCircle(center: Offset.zero, radius: 10 * pulseScale);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawCircle(Offset.zero, 10 * pulseScale, paint);

    // Inner core
    canvas.drawCircle(
      Offset.zero,
      5 * pulseScale,
      Paint()..color = Colors.white.withOpacity(0.8),
    );

    // Flame particles
    final random = math.Random(position.x.toInt());
    for (int i = 0; i < 5; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final distance = random.nextDouble() * 8;
      final x = math.cos(angle) * distance;
      final y = math.sin(angle) * distance;

      canvas.drawCircle(
        Offset(x, y),
        random.nextDouble() * 2 + 1,
        Paint()..color = Colors.yellow.withOpacity(0.6),
      );
    }
  }

  void _renderKnife(Canvas canvas) {
    canvas.save();
    canvas.rotate(rotation + pulseTimer * 10);

    // Knife blade
    final bladePath = Path()
      ..moveTo(-8, 0)
      ..lineTo(8, -3)
      ..lineTo(10, 0)
      ..lineTo(8, 3)
      ..close();

    canvas.drawPath(
      bladePath,
      Paint()..color = Colors.grey[300]!,
    );

    // Blade shine
    canvas.drawPath(
      bladePath,
      Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Handle
    canvas.drawRect(
      const Rect.fromLTWH(-10, -2, 4, 4),
      Paint()..color = Colors.brown[700]!,
    );

    canvas.restore();

    // Motion blur
    canvas.drawCircle(
      Offset.zero,
      12,
      Paint()
        ..color = color.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _renderArrow(Canvas canvas) {
    canvas.save();
    canvas.rotate(rotation);

    // Arrow shaft
    canvas.drawRect(
      const Rect.fromLTWH(-12, -1.5, 20, 3),
      Paint()..color = Colors.brown[600]!,
    );

    // Arrow tip
    final tipPath = Path()
      ..moveTo(8, 0)
      ..lineTo(12, -4)
      ..lineTo(12, 4)
      ..close();

    canvas.drawPath(
      tipPath,
      Paint()..color = Colors.grey[700]!,
    );

    // Fletching
    final fletchPath = Path()
      ..moveTo(-12, 0)
      ..lineTo(-8, -3)
      ..lineTo(-8, 3)
      ..close();

    canvas.drawPath(
      fletchPath,
      Paint()..color = Colors.red[800]!,
    );

    canvas.restore();

    // Speed lines
    final speedPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;

    for (int i = 0; i < 3; i++) {
      final offset = -direction * (10.0 + i * 5);
      canvas.drawLine(
        Offset(offset.x, offset.y - 2 + i),
        Offset(offset.x - 15, offset.y - 2 + i),
        speedPaint,
      );
    }
  }

  void _renderDefault(Canvas canvas) {
    // Outer glow
    canvas.drawCircle(
      Offset.zero,
      12,
      Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Main circle
    canvas.drawCircle(
      Offset.zero,
      8,
      Paint()..color = color,
    );

    // Highlight
    canvas.drawCircle(
      const Offset(-2, -2),
      3,
      Paint()..color = Colors.white.withOpacity(0.6),
    );

    // Border
    canvas.drawCircle(
      Offset.zero,
      8,
      Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _createImpactEffect() {
    // Add impact particle effect
    final impact = ImpactEffect(
      position: position.clone(),
      color: color,
    );
    game.add(impact);
  }
}