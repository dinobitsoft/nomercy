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

  /// Extra tiles drawn beyond each viewport edge — prevents pop-in on fast
  /// camera movement.
  static const int _bleedTiles = 3;

  /// Huge width so Flame's frustum culler never removes this component.
  /// Has no effect on tile drawing logic.
  static const double _cullWidth = 1e8;

  /// Set to true to draw a red outline + index label on every tile.
  /// Flip off before shipping.
  static const bool _debugDraw = true;

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

    final (worldLeft, worldRight) = _visibleWorldBounds();

    final firstIdx = (worldLeft  / _step).floor() - _bleedTiles;
    final lastIdx  = (worldRight / _step).ceil()  + _bleedTiles;

    if (_loaded && _tile != null) {
      _drawTiles(canvas);
    } else {
      _drawFallback(canvas);
    }
    canvas.restore();

    if (_debugDraw) _drawDebugOverlay(canvas, firstIdx, lastIdx, worldLeft, worldRight);
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
    final paint = Paint()..filterQuality = FilterQuality.low;

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

  void _drawDebugOverlay(
      Canvas canvas, int firstIdx, int lastIdx,
      double worldLeft, double worldRight,
      ) {
    final outlinePaint = Paint()
      ..color       = Colors.red.withOpacity(0.6)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;

    final vpPaint = Paint()
      ..color       = Colors.yellow.withOpacity(0.4)
      ..strokeWidth = 2
      ..style       = PaintingStyle.stroke;

    // Draw viewport boundary in canvas space.
    canvas.drawRect(
      Rect.fromLTRB(
        worldLeft  - position.x, -tileSize / 2,
        worldRight - position.x,  tileSize / 2,
      ),
      vpPaint,
    );

    // Draw outline + index on each tile.
    for (int idx = firstIdx; idx <= lastIdx; idx++) {
      final lx = _canvasX(idx);
      canvas.drawRect(
        Rect.fromLTWH(lx, -tileSize / 2, tileSize, tileSize),
        outlinePaint,
      );

      final para = _buildTextParagraph(
        '$idx\n(${(idx * _step).toInt()})',
        fontSize: 9,
        color: Colors.red,
      );
      canvas.drawParagraph(para, Offset(lx + 4, -tileSize / 2 + 4));
    }

    // Component centre marker.
    canvas.drawCircle(
      Offset.zero,
      6,
      Paint()..color = Colors.lime,
    );

    debugPrint(
      '[Ground] pos.x=${position.x.toStringAsFixed(0)} '
          'world=[${ worldLeft.toStringAsFixed(0)}, ${worldRight.toStringAsFixed(0)}] '
          'tiles=[$firstIdx..$lastIdx] '
          'tile=${_loaded ? '${_tile!.width}×${_tile!.height}' : 'fallback'}',
    );
  }

  ui.Paragraph _buildTextParagraph(String text, {double fontSize = 10, Color color = Colors.white}) {
    final style = ui.ParagraphStyle(textAlign: TextAlign.left);
    final builder = ui.ParagraphBuilder(style)
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        background: Paint()..color = Colors.black.withOpacity(0.5),
      ))
      ..addText(text);
    return builder.build()..layout(const ui.ParagraphConstraints(width: 100));
  }

  double _canvasX(int idx) => idx * _step - position.x;

  (double, double) _visibleWorldBounds() {
    // 1. Modern Flame CameraComponent API.
    try {
      final r = game.camera.visibleWorldRect;
      if (r.width > 0) return (r.left, r.right);
    } catch (_) {}

    // 2. Legacy: viewport size centred on the player.
    try {
      final halfW = game.size.x / 2;
      final cx    = game.character.position.x;
      return (cx - halfW, cx + halfW);
    } catch (_) {}

    // 3. Last resort.
    return (position.x - 1000, position.x + 1000);
  }
}