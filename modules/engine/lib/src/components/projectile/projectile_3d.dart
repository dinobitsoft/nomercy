// modules/engine/lib/src/components/projectile/projectile_3d.dart

import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A projectile in 3D world space.
///
/// Travels along [velocity3D] (world units / sec), projects to screen each
/// frame via [IsoProjection], and checks AABB3D hits against the player or
/// enemies.
class Projectile3D extends PositionComponent with HasGameReference<ActionGame3D> {
  // ── world state ──────────────────────────────────────────────────────────────
  WorldPos worldPos;
  final WorldPos velocity3D;

  // ── config ───────────────────────────────────────────────────────────────────
  final double damage;
  final bool   fromPlayer; // true → hits enemies; false → hits player
  final String type;       // 'fireball' | 'knife' | 'arrow' | 'default'
  final Color  color;

  double _lifetime = 4.0;
  double _pulse    = 0;

  // simple trail
  final List<WorldPos> _trail = [];
  double _trailTimer = 0;

  static const double speed      = 750.0;
  static const double _hitRadius = 80.0;   // world-unit hit sphere
  static const double _gravity   = 380.0;  // world-units/s² — ~38% of char gravity

  /// Exposed so callers can compute lob compensation for the same gravity value.
  static double get gravity => _gravity;

  Projectile3D({
    required WorldPos spawnPos,
    required this.velocity3D,
    required this.damage,
    required this.fromPlayer,
    required this.type,
    required this.color,
  })  : worldPos = spawnPos.clone(),
        super(
          size:     Vector2.all(24),
          anchor:   Anchor.center,
          priority: 500,
        );

  // ── update ───────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _lifetime -= dt;
    _pulse    += dt;

    // Gravity arc
    velocity3D.y -= _gravity * dt;

    // Integrate position
    worldPos.x += velocity3D.x * dt;
    worldPos.y += velocity3D.y * dt;
    worldPos.z += velocity3D.z * dt;

    // Trail
    _trailTimer += dt;
    if (_trailTimer > 0.04) {
      _trail.add(worldPos.clone());
      _trailTimer = 0;
      if (_trail.length > 6) _trail.removeAt(0);
    }

    // ── Environment collision ──────────────────────────────────────────────
    // Ground
    if (worldPos.y <= GameConfig3D.groundSurfaceY) {
      _explode();
      return;
    }

    // Platforms
    for (final p in game.platforms3D) {
      final b = p.aabb;
      if (worldPos.x >= b.minX && worldPos.x <= b.maxX &&
          worldPos.y >= b.minY && worldPos.y <= b.maxY &&
          worldPos.z >= b.minZ && worldPos.z <= b.maxZ) {
        _explode();
        return;
      }
    }

    // Obstacles
    for (final o in game.obstacles3D) {
      final b = o.aabb;
      if (worldPos.x >= b.minX && worldPos.x <= b.maxX &&
          worldPos.y >= b.minY && worldPos.y <= b.maxY &&
          worldPos.z >= b.minZ && worldPos.z <= b.maxZ) {
        _explode();
        return;
      }
    }

    // Sync Flame screen position
    final origin = game.worldOriginOnScreen;
    position = IsoProjection.projectXYZ(
      worldPos.x, worldPos.y, worldPos.z,
      screenOrigin: origin,
    );

    // ── Character hit detection ────────────────────────────────────────────
    if (fromPlayer) {
      for (final enemy in game.enemies) {
        if (enemy.characterState.health <= 0) continue;
        if (_dist(enemy.worldPos) < _hitRadius) {
          enemy.takeDamage3D(damage,
              knockback: WorldPos(velocity3D.x * 0.3, 150, velocity3D.z * 0.3));
          _explode();
          return;
        }
      }
    } else {
      if (_dist(game.character.worldPos) < _hitRadius) {
        game.character.takeDamage3D(damage);
        _explode();
        return;
      }
    }

    if (_lifetime <= 0) _remove();
  }

  double _dist(WorldPos other) {
    final dx = worldPos.x - other.x;
    // other.y is the character's bottom; measure to centre of body.
    final dy = worldPos.y - (other.y + GameConfig3D.characterSizeY * 0.5);
    final dz = worldPos.z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  void _explode() {
    // Small impact flash
    final flash = _ImpactFlash3D(worldPos: worldPos.clone(), color: color);
    game.world.add(flash);
    _remove();
  }

  void _remove() {
    game.projectiles3D.remove(this);
    if (isMounted) removeFromParent();
  }

  // ── render ───────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    // Trail
    if (_trail.length >= 2) {
      final origin = game.worldOriginOnScreen;
      for (int i = 0; i < _trail.length - 1; i++) {
        final a = IsoProjection.projectXYZ(
          _trail[i].x, _trail[i].y, _trail[i].z, screenOrigin: origin) - position;
        final b = IsoProjection.projectXYZ(
          _trail[i + 1].x, _trail[i + 1].y, _trail[i + 1].z, screenOrigin: origin) - position;
        canvas.drawLine(
          Offset(a.x, a.y), Offset(b.x, b.y),
          Paint()
            ..color = color.withOpacity((i / _trail.length) * 0.45)
            ..strokeWidth = 3 - (i / _trail.length) * 1.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    switch (type) {
      case 'fireball': _renderFireball(canvas);
      case 'knife':    _renderKnife(canvas);
      case 'arrow':    _renderArrow(canvas);
      default:         _renderDefault(canvas);
    }
  }

  void _renderFireball(Canvas canvas) {
    final pulse = 1.0 + math.sin(_pulse * 10) * 0.2;
    canvas.drawCircle(Offset.zero, 16,
        Paint()..color = Colors.orange.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    final rect = Rect.fromCircle(center: Offset.zero, radius: 11 * pulse);
    canvas.drawCircle(Offset.zero, 11 * pulse, Paint()
      ..shader = const RadialGradient(
        colors: [Colors.yellow, Colors.orange, Colors.red],
        stops: [0, 0.5, 1],
      ).createShader(rect));
    canvas.drawCircle(Offset.zero, 5 * pulse,
        Paint()..color = Colors.white.withOpacity(0.9));
  }

  void _renderKnife(Canvas canvas) {
    canvas.save();
    // Point in direction of travel (XZ projected angle)
    final angle = math.atan2(velocity3D.x * IsoProjection.kZX, velocity3D.z);
    canvas.rotate(angle + _pulse * 8);
    final blade = Path()
      ..moveTo(-8, 0) ..lineTo(8, -3) ..lineTo(10, 0) ..lineTo(8, 3) ..close();
    canvas.drawPath(blade, Paint()..color = Colors.grey[300]!);
    canvas.drawPath(blade, Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawRect(const Rect.fromLTWH(-10, -2, 4, 4),
        Paint()..color = Colors.brown[700]!);
    canvas.restore();
  }

  void _renderArrow(Canvas canvas) {
    canvas.save();
    final angle = math.atan2(velocity3D.x * IsoProjection.kZX, velocity3D.z);
    canvas.rotate(angle);
    canvas.drawRect(const Rect.fromLTWH(-12, -1.5, 20, 3),
        Paint()..color = Colors.brown[600]!);
    canvas.drawPath(
      Path()..moveTo(8, 0) ..lineTo(12, -4) ..lineTo(12, 4) ..close(),
      Paint()..color = Colors.grey[700]!,
    );
    canvas.drawPath(
      Path()..moveTo(-12, 0) ..lineTo(-8, -3) ..lineTo(-8, 3) ..close(),
      Paint()..color = Colors.red[800]!,
    );
    canvas.restore();
  }

  void _renderDefault(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 10, Paint()..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(Offset.zero, 7, Paint()..color = color);
    canvas.drawCircle(const Offset(-2, -2), 3,
        Paint()..color = Colors.white.withOpacity(0.6));
  }
}

// ── small impact flash (auto-removes) ─────────────────────────────────────────

class _ImpactFlash3D extends PositionComponent with HasGameReference<ActionGame3D> {
  final WorldPos worldPos;
  final Color    color;
  double _life = 0.25;

  _ImpactFlash3D({required this.worldPos, required this.color})
      : super(size: Vector2.all(40), anchor: Anchor.center, priority: 600);

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    final origin = game.worldOriginOnScreen;
    position = IsoProjection.projectXYZ(
      worldPos.x, worldPos.y, worldPos.z, screenOrigin: origin);
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / 0.25).clamp(0.0, 1.0);
    canvas.drawCircle(Offset.zero, 20 * (1 - t) + 8,
        Paint()..color = color.withOpacity(t * 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * t));
    canvas.drawCircle(Offset.zero, 8 * t,
        Paint()..color = Colors.white.withOpacity(t * 0.9));
  }
}
