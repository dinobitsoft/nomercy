import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Infinite ground strip that:
///   1. Follows the player horizontally (and covers ALL active bots — Fix #3).
///   2. Draws tiles symmetrically around its centre (Fix #2).
///   3. The visual top edge sits at groundSurfaceY so characters stand flush
///      on the visible tile (Fix #1 — no more −100 magic offset).
class TiledGroundComponent extends GamePlatform {
  static const double tileSize  = 128.0;
  static const double overlapPx = 78.0;

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
  );

  // ── loading ────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final name in ['ground_tile.png']) {
      try {
        _tile = await game.images.load(name);
        _loaded = true;
        print('✅ TiledGroundComponent loaded "$name"');
        break;
      } catch (_) {}
    }
    if (!_loaded) print('⚠️  TiledGroundComponent: no texture, using fallback');
  }

  // ── update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    try {
      final char = game.character;

      // ── FIX #3: extend strip to cover ALL living enemies, not just player ──
      double leftmost  = char.position.x;
      double rightmost = char.position.x;

      for (final enemy in game.enemies) {
        if (!enemy.isMounted) continue;
        leftmost  = math.min(leftmost,  enemy.position.x);
        rightmost = math.max(rightmost, enemy.position.x);
      }

      // Centre the component between the extremes, pad each side.
      final span   = (rightmost - leftmost).abs();
      position.x   = (leftmost + rightmost) / 2;
      size.x       = span + _sidePad * 2;
    } catch (_) {
      // character not yet initialised — keep fallback size (4000)
    }
  }

  // ── render ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
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

  /// ── FIX #2: symmetric tile placement around component centre ──────────────
  ///
  /// Old code computed worldLeft then iterated forward, which caused tiles to
  /// only appear left of the player when the first-tile index was off.
  /// New approach: start from the tile index at the centre and expand outward
  /// in both directions — always symmetric regardless of world position.
  void _drawTiles(Canvas canvas) {
    final step   = tileSize - overlapPx; // 50 px advance per tile
    final half   = (size.x / 2 / step).ceil() + 2; // tiles needed each side

    // Tile index whose left edge is nearest to the component centre.
    final centreIdx = (position.x / step).round();
    final firstIdx  = centreIdx - half;
    final lastIdx   = centreIdx + half;

    final src   = Rect.fromLTWH(0, 0, _tile!.width.toDouble(), _tile!.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.medium;

    for (int idx = firstIdx; idx <= lastIdx; idx++) {
      final worldX = idx * step;
      final localX = worldX - position.x; // relative to component anchor (centre)
      final localY = -size.y / 2;         // top edge of strip
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

    final step  = tileSize - overlapPx;
    final half  = (size.x / 2 / step).ceil() + 2;
    final cIdx  = (position.x / step).round();
    final lp    = Paint()
      ..color       = Colors.black.withOpacity(0.15)
      ..strokeWidth = 1;

    for (int i = cIdx - half; i <= cIdx + half; i++) {
      final lx = i * step - position.x;
      canvas.drawLine(Offset(lx, -size.y / 2), Offset(lx, size.y / 2), lp);
    }
  }
}