import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../core/game_event.dart';
import '../../game/action_game.dart';
import '../../core/event_bus.dart';
import '../../game/game_character.dart';
import '../../impact_effect.dart';
import '../../managers/network_manager.dart';

class Projectile extends PositionComponent with HasGameReference<ActionGame> {
  Vector2 direction;
  double damage;
  GameCharacter? owner;  // null if from bot
  GameCharacter? enemyOwner;  // null if from player
  Color color;
  String type;  // 'knife', 'fireball', 'arrow'
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
    priority = 50;
    // Calculate rotation based on direction
    rotation = math.atan2(direction.y, direction.x);
  }

  @override
  void onLoad() async {
    super.onLoad();

    // FIX: Ensure projectile is always visible by setting explicit render priority
    // This prevents it from being hidden behind other components
    priority = 75; // Between platforms (10) and characters (90-100)

    print('🎯 Projectile loaded: type=$type, position=$position, color=$color, priority=$priority');
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

    // Check collision with player (if from bot or remote player)
    if (enemyOwner != null) {
      if (position.distanceTo(game.player.position) < 30) {
        game.player.takeDamage(damage);
        
        // Refactored: Emit event and creation of impact effect is handled there if needed, 
        // but here we call it directly as before, ensuring consistency.
        EventBus().emit(CharacterDamagedEvent(
          characterId: game.player.stats.name, 
          damage: damage, 
          remainingHealth: game.player.health, 
          healthPercent: (game.player.health / 100) * 100, // Assuming 100 is max
          damageSource: 'projectile'
        ));
        
        _createImpactEffect();
        removeFromParent();
        game.projectiles.remove(this);
        return;
      }
    }

    // Check collision with enemies (if from player)
    if (owner != null) {
      // Check AI enemies
      for (final enemy in game.enemies) {
        if (position.distanceTo(enemy.position) < 30) {
          enemy.takeDamage(damage);
          
          EventBus().emit(CharacterDamagedEvent(
            characterId: enemy.stats.name,
            damage: damage,
            remainingHealth: enemy.health,
            healthPercent: (enemy.health / 100) * 100,
            damageSource: 'projectile'
          ));

          _createImpactEffect();
          removeFromParent();
          game.projectiles.remove(this);
          return;
        }
      }

      // Check remote players in multiplayer mode
      if (game.enableMultiplayer) {
        for (final entry in NetworkManager().remotePlayers.entries) {
          final remotePlayer = entry.value;
          final playerId = entry.key;

          if (remotePlayer.health > 0 && position.distanceTo(remotePlayer.position) < 30) {
            // Send damage to server
            NetworkManager().sendDamage(playerId, damage);
            
            EventBus().emit(CharacterDamagedEvent(
              characterId: remotePlayer.stats.name,
              damage: damage,
              remainingHealth: remotePlayer.health,
              healthPercent: (remotePlayer.health / 100) * 100,
              damageSource: 'projectile'
            ));

            _createImpactEffect();
            removeFromParent();
            game.projectiles.remove(this);
            return;
          }
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

    // Uncomment this line to debug projectile visibility issues:
    // _renderDebugInfo(canvas);
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
    // FIX: Make fireball more visible with enhanced effects

    // Outer glow - make it bigger and brighter
    final glowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.6) // Increased from 0.4
      ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal, 12); // Increased from 8
    canvas.drawCircle(Offset.zero, 20, glowPaint); // Increased from 15

    // Pulsing effect
    final pulseScale = 1.0 + math.sin(pulseTimer * 10) * 0.2;

    // Main fireball - make it larger
    final gradient = RadialGradient(
      colors: [
        Colors.yellow,
        Colors.orange,
        Colors.red.withOpacity(0.9), // Increased opacity
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final rect = Rect.fromCircle(
        center: Offset.zero, radius: 12 * pulseScale); // Increased from 10
    final paint = Paint()
      ..shader = gradient.createShader(rect);
    canvas.drawCircle(Offset.zero, 12 * pulseScale, paint);

    // Inner core - brighter
    canvas.drawCircle(
      Offset.zero,
      6 * pulseScale, // Increased from 5
      Paint()
        ..color = Colors.white.withOpacity(0.9), // Increased opacity
    );

    // Flame particles - more visible
    final random = math.Random(position.x.toInt());
    for (int i = 0; i < 8; i++) { // Increased from 5
      final angle = random.nextDouble() * math.pi * 2;
      final distance = random.nextDouble() * 10; // Increased from 8
      final x = math.cos(angle) * distance;
      final y = math.sin(angle) * distance;

      canvas.drawCircle(
        Offset(x, y),
        random.nextDouble() * 3 + 1, // Increased size
        Paint()
          ..color = Colors.yellow.withOpacity(0.8), // Increased opacity
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

  void _renderDebugInfo(Canvas canvas) {
    // Only in debug mode - you can disable this later
    final debugPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw bounding box
    canvas.drawCircle(Offset.zero, 15, debugPaint);

    // Draw direction indicator
    final dirLine = direction * 20;
    canvas.drawLine(
      Offset.zero,
      Offset(dirLine.x, dirLine.y),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 3,
    );
  }
}
