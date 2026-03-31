import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Infinite ground strip.
/// Always covers: camera viewport + every character + _pad buffer on each side.
/// anchor = Anchor.center — position.x is the world midpoint.
class TiledGroundComponent extends GamePlatform {
  static const double tileSize   = 128.0;
  static const double overlapPx  = 78.0;
  static const double _step      = tileSize - overlapPx; // 50 px per tile advance
  static const double _pad       = 800.0;                 // extra coverage each side
  static const int    _bleed     = 4;                     // extra tile bleed beyond clip
  static const bool   _debugDraw = false;

  ui.Image? _tile;
  bool _loaded = false;

  TiledGroundComponent({required double groundY})
      : super(
    position: Vector2(0, groundY),
    size: Vector2(4000, tileSize),
    platformType: 'ground',
  ) {
    anchor = Anchor.center;
  }

  // ── loading ────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final name in ['ground_tile.png', 'ground.png']) {
      try {
        _tile = await game.images.load(name);
        _loaded = true;
        debugPrint('✅ TiledGroundComponent: "$name"');
        break;
      } catch (_) {}
    }
    if (!_loaded) debugPrint('⚠️  TiledGroundComponent: no texture, fallback');
  }

  // ── update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _updateCoverage();
  }

  void _updateCoverage() {
    try {
      // Start with camera visible world rect
      final rect  = game.camera.visibleWorldRect;
      double left  = rect.left;
      double right = rect.right;

      // Extend to every mounted character so ground is always under bots
      for (final c in game.characterRegistry.values) {
        if (!c.isMounted) continue;
        left  = math.min(left,  c.position.x);
        right = math.max(right, c.position.x);
      }

      left  -= _pad;
      right += _pad;

      position.x = (left + right) / 2.0;
      size.x     = math.max(right - left, 4000.0); // never shrink below 4000
    } catch (_) {
      // character / camera not ready yet
      try {
        position.x = game.character.position.x;
      } catch (_) {}
      size.x = 4000.0;
    }
  }

  // ── render ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    // With Anchor.center, (0,0) == component centre in canvas space.
    canvas.save();
    canvas.clipRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
    );

    if (_loaded && _tile != null) {
      _drawTiles(canvas);
    } else {
      _drawFallback(canvas);
    }

    canvas.restore();

    if (_debugDraw) _drawDebugOverlay(canvas);
  }

  /// Tile placement algorithm:
  ///   canvas (0,0) == world position.x (guaranteed by Anchor.center)
  ///   tileLocalX = tileWorldX − position.x
  void _drawTiles(Canvas canvas) {
    final tw    = _tile!.width.toDouble();
    final th    = _tile!.height.toDouble();
    final half  = (size.x / 2 / _step).ceil() + _bleed;
    final cIdx  = (position.x / _step).round();
    final src   = Rect.fromLTWH(0, 0, tw, th);
    final paint = Paint()..filterQuality = FilterQuality.low;
    final topY  = -size.y / 2;

    for (int idx = cIdx - half; idx <= cIdx + half; idx++) {
      final localX = idx * _step - position.x;
      canvas.drawImageRect(
        _tile!,
        src,
        Rect.fromLTWH(localX, topY, tileSize, tileSize),
        paint,
      );
    }
  }

  void _drawFallback(Canvas canvas) {
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      Paint()..color = const Color(0xFF3a7d44),
    );
    final half = (size.x / 2 / _step).ceil() + _bleed;
    final cIdx = (position.x / _step).round();
    final lp   = Paint()
      ..color       = Colors.black.withOpacity(0.15)
      ..strokeWidth = 1;
    for (int i = cIdx - half; i <= cIdx + half; i++) {
      final lx = i * _step - position.x;
      canvas.drawLine(
        Offset(lx, -size.y / 2),
        Offset(lx,  size.y / 2),
        lp,
      );
    }
  }

  void _drawDebugOverlay(Canvas canvas) {
    final outlinePaint = Paint()
      ..color       = Colors.red.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;

    final half = (size.x / 2 / _step).ceil() + _bleed;
    final cIdx = (position.x / _step).round();

    for (int idx = cIdx - half; idx <= cIdx + half; idx++) {
      final lx = idx * _step - position.x;
      canvas.drawRect(
        Rect.fromLTWH(lx, -tileSize / 2, tileSize, tileSize),
        outlinePaint,
      );
    }
    canvas.drawCircle(Offset.zero, 6, Paint()..color = Colors.lime);
  }
}