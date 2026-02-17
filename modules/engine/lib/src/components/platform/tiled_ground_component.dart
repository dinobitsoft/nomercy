import 'dart:ui' as ui;

import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class TiledGroundComponent extends GamePlatform {
  static const double tileSize   = 128.0;
  static const double overlapPx  = 78.0;
  static const double _bufferPad = tileSize * 8;

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

    // FIX: single try/catch wraps ALL character access — the old code had the
    // safe block AND then the same access AGAIN outside the catch, which would
    // throw a LateInitializationError on early frames before character is ready.
    try {
      final char = game.character;
      position.x = char.position.x;
      final vpWidth = game.size.x / game.camera.viewfinder.zoom;
      size.x = vpWidth + _bufferPad;
    } catch (_) {
      // character not yet initialized — keep initial position (x=0, size.x=4000)
      // which is wide enough to cover any spawn point.
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

  void _drawTiles(Canvas canvas) {
    final double step      = tileSize - overlapPx;
    final double worldLeft = position.x - size.x / 2;
    final int    firstIdx  = (worldLeft / step).floor() - 1;
    final int    count     = (size.x / step).ceil() + 2;

    final ui.Image tile = _tile!;
    final src   = Rect.fromLTWH(0, 0, tile.width.toDouble(), tile.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.high;

    for (int i = 0; i < count; i++) {
      final double worldX = (firstIdx + i) * step;
      final double localX = worldX - position.x;
      final double localY = -size.y / 2 ;
      canvas.drawImageRect(tile, src, Rect.fromLTWH(localX, localY, tileSize, tileSize), paint);
    }
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