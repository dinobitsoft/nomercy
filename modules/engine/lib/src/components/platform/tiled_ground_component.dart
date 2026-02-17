import 'dart:ui' as ui;

import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class TiledGroundComponent extends GamePlatform {
  static const double tileSize   = 128.0;
  static const double overlapPx  = 2.0;
  static const double _bufferPad = tileSize * 8;

  ui.Image? _tile;
  bool _loaded = false;
  bool _characterReady = false;  // guard against LateInitializationError

  TiledGroundComponent({required double groundY})
      : super(
    position: Vector2(0, groundY),
    size: Vector2(4000, tileSize),  // safe large initial width
    platformType: 'ground',
  );

  // ── loading ────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    for (final name in ['ground_tile.png', 'ground.png']) {
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

    // Safe character access — game.character is `late`, throws if unset.
    try {
      final char = game.character;
      // Update position every frame once ready.
      position.x = char.position.x;
      final vpWidth = game.size.x / game.camera.viewfinder.zoom;
      size.x = vpWidth + _bufferPad;
    } catch (_) {
      // Character not yet initialized — keep current position (x=0, large width).
      // The initial size.x=4000 is wide enough to cover any spawn.
    }

    // Center collision box on the player so it covers them at all times.
    position.x = game.character.position.x;

    // Match viewport width + buffer so off-screen enemies also hit the ground.
    final vpWidth = game.size.x / game.camera.viewfinder.zoom;
    size.x = vpWidth + _bufferPad;
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
      _drawTopHighlight(canvas);
    } else {
      _drawFallback(canvas);
    }
    canvas.restore();
  }

  void _drawTiles(Canvas canvas) {
    final double step     = tileSize - overlapPx;
    final double worldLeft = position.x - size.x / 2;
    final int    firstIdx  = (worldLeft / step).floor() - 1;
    final int    count     = (size.x / step).ceil() + 2;

    final ui.Image tile = _tile!;
    final src   = Rect.fromLTWH(0, 0, tile.width.toDouble(), tile.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.low;

    for (int i = 0; i < count; i++) {
      final double worldX = (firstIdx + i) * step;
      final double localX = worldX - position.x;
      final double localY = -size.y / 2;
      canvas.drawImageRect(tile, src, Rect.fromLTWH(localX, localY, tileSize, tileSize), paint);
    }
  }

  void _drawTopHighlight(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(-size.x / 2, -size.y / 2, size.x, 3),
      Paint()..color = Colors.white.withOpacity(0.25),
    );
  }

  void _drawFallback(Canvas canvas) {
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y),
      Paint()..color = const Color(0xFF3a7d44),
    );
    final lp    = Paint()..color = Colors.black.withOpacity(0.15)..strokeWidth = 1;
    final step  = tileSize - overlapPx;
    final wLeft = position.x - size.x / 2;
    final first = (wLeft / step).floor();
    final cnt   = (size.x / step).ceil() + 2;
    for (int i = 0; i < cnt; i++) {
      final lx = (first + i) * step - position.x;
      canvas.drawLine(Offset(lx, -size.y / 2), Offset(lx, size.y / 2), lp);
    }
  }
}