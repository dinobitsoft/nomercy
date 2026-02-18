import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Infinite ground strip that:
///   1. Follows the player horizontally (and covers ALL active bots).
///   2. Draws tiles symmetrically around its centre.
///   3. The visual top edge sits at groundSurfaceY so characters stand flush.
///
/// IMPORTANT: anchor = Anchor.center — position.x IS the world midpoint.
/// All render math depends on this; do not change the anchor without
/// updating _drawTiles / _drawFallback accordingly.
class TiledGroundComponent extends GamePlatform {
  static const double tileSize  = 128.0;
  static const double overlapPx = 78.0;

  /// Effective horizontal advance per tile (tile width minus overlap).
  static const double _step = tileSize - overlapPx; // 50 px

  /// Extra world-units to extend beyond the outermost tracked character on
  /// each side.  One full viewport + a few tiles of safety.
  static const double _sidePad = 1200.0;

  ui.Image? _tile;
  bool _loaded = false;

  TiledGroundComponent({required double groundY})
      : super(
    position: Vector2(0, groundY),
    size: Vector2(4000, tileSize),
    platformType: 'ground',
  ) {
    // ── FIX (root cause): render assumes Offset.zero == component centre. ──
    // Without this, the canvas origin is the top-left corner and the
    // symmetric clip / tile math places tiles only to the left of the player.
    anchor = Anchor.center;
  }

  // ── loading ────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final name in ['ground_tile.png']) {
      try {
        _tile = await game.images.load(name);
        _loaded = true;
        debugPrint('✅ TiledGroundComponent loaded "$name"');
        break;
      } catch (_) {}
    }
    if (!_loaded) debugPrint('⚠️  TiledGroundComponent: no texture, using fallback');
  }

  // ── update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    try {
      final char = game.character;

      double leftmost  = char.position.x;
      double rightmost = char.position.x;

      for (final enemy in game.enemies) {
        if (!enemy.isMounted) continue;
        leftmost  = math.min(leftmost,  enemy.position.x);
        rightmost = math.max(rightmost, enemy.position.x);
      }

      // Centre anchor → position.x is the visual midpoint of the strip.
      position.x = (leftmost + rightmost) / 2;
      size.x     = (rightmost - leftmost).abs() + _sidePad * 2;
    } catch (_) {
      // character not yet initialised — keep fallback size (4000)
    }
  }

  // ── render ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    // With Anchor.center, (0,0) IS the component centre in canvas space.
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
  }

  /// Symmetric tile placement around component centre.
  ///
  /// Canvas origin == component centre (guaranteed by Anchor.center).
  /// worldCentreX  == position.x (Flame keeps these in sync).
  ///
  /// Algorithm:
  ///   1. Find the tile grid index closest to the world centre.
  ///   2. Compute how many tiles are needed to fill each half.
  ///   3. For each tile: localX = its world position − world centre.
  ///      This is exactly its canvas offset because canvas origin == centre.
  void _drawTiles(Canvas canvas) {
    final half = (size.x / 2 / _step).ceil() + 2;

    // World-aligned tile index nearest to the component's world centre.
    final centreIdx = (position.x / _step).round();

    final src   = Rect.fromLTWH(0, 0, _tile!.width.toDouble(), _tile!.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.medium;

    for (int idx = centreIdx - half; idx <= centreIdx + half; idx++) {
      final worldX = idx * _step;
      // localX: distance from world centre → canvas offset (Anchor.center).
      final localX = worldX - position.x;
      // Top of tile = top edge of strip (−half height from centre).
      final localY = -size.y / 2;
      canvas.drawImageRect(
        _tile!,
        src,
        Rect.fromLTWH(localX, localY, tileSize, tileSize),
        paint,
      );
    }
  }

  void _drawFallback(Canvas canvas) {
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      Paint()..color = const Color(0xFF3a7d44),
    );

    final half  = (size.x / 2 / _step).ceil() + 2;
    final cIdx  = (position.x / _step).round();
    final lp    = Paint()
      ..color       = Colors.black.withOpacity(0.15)
      ..strokeWidth = 1;

    for (int i = cIdx - half; i <= cIdx + half; i++) {
      final lx = i * _step - position.x;
      canvas.drawLine(Offset(lx, -size.y / 2), Offset(lx, size.y / 2), lp);
    }
  }
}