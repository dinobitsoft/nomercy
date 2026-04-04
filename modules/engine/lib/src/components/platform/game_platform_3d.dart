// modules/engine/lib/src/components/platform/game_platform_3d.dart

import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 3D platform rendered via oblique projection.
///
/// Internal state: 3D world-space AABB ([worldPos] is the center of the
/// *top face*; sizeZ is depth, sizeX is width, sizeY is block height).
///
/// The Flame [position] / [size] are recomputed each frame from the
/// projection so the engine's camera / culling work correctly.
class GamePlatform3D extends PositionComponent
    with HasGameReference<ActionGame3D> {

  // ── 3D world geometry ─────────────────────────────────────────────────────
  WorldPos worldPos;        // centre of top face in world space
  final double sizeX;       // width  (X axis)
  final double sizeY;       // height (Y axis) — visual block height
  final double sizeZ;       // depth  (Z axis)

  final String platformType;

  // ── visual ────────────────────────────────────────────────────────────────
  Color topColor  = const Color(0xFF4a7c59);
  Color sideColor = const Color(0xFF2d5a3d);
  Color frontColor= const Color(0xFF3d6b4a);

  bool _loaded = false;
  ui.Image? _tileTexture;   // tiled across top + faces

  GamePlatform3D({
    required this.worldPos,
    required this.sizeX,
    required this.sizeY,
    required this.sizeZ,
    required this.platformType,
    int priority = 0,
  }) : super(anchor: Anchor.topLeft, priority: priority);

  // ── AABB helpers ──────────────────────────────────────────────────────────

  /// Top face Y (characters land on this).
  double get topY    => worldPos.y;
  double get bottomY => worldPos.y - sizeY;

  AABB3D get aabb => AABB3D(
    minX: worldPos.x - sizeX / 2,  maxX: worldPos.x + sizeX / 2,
    minY: bottomY,                  maxY: topY,
    minZ: worldPos.z - sizeZ / 2,  maxZ: worldPos.z + sizeZ / 2,
  );

  /// True when character footprint (XZ) overlaps this platform.
  bool footprintOverlaps(AABB3D charAabb) => aabb.overlapsXZ(charAabb);

  // ── depth sort ────────────────────────────────────────────────────────────

  void updateDepthPriority() {
    priority = IsoProjection.depthPriority(worldPos);
  }

  // ── onLoad ────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _applyPlatformColors();

    // Try tile texture first (same assets as 2D TiledPlatform), then plain.
    for (final name in ['${platformType}_tile.png', '$platformType.png']) {
      try {
        _tileTexture = await game.images.load(name);
        _loaded = true;
        break;
      } catch (_) {}
    }

    _syncFlamePosition();
  }

  void _applyPlatformColors() {
    switch (platformType) {
      case 'ground':
        topColor   = const Color(0xFF6aaa54);
        frontColor = const Color(0xFF3a6828);
        sideColor  = const Color(0xFF2a5018);
      case 'brick':
        topColor   = const Color(0xFFc08860);
        frontColor = const Color(0xFF804830);
        sideColor  = const Color(0xFF603820);
      case 'stone':
        topColor   = const Color(0xFF9090a8);
        frontColor = const Color(0xFF505060);
        sideColor  = const Color(0xFF383848);
      case 'ice':
        topColor   = const Color(0xFFc8eaff);
        frontColor = const Color(0xFF5090c0);
        sideColor  = const Color(0xFF306888);
      default:
        topColor   = const Color(0xFF8080c8);
        frontColor = const Color(0xFF404090);
        sideColor  = const Color(0xFF282860);
    }
  }

  // ── update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _syncFlamePosition();
    updateDepthPriority();
  }

  /// Keep Flame [position] / [size] aligned with projected corners so the
  /// camera, HUD and culling system see the right screen footprint.
  void _syncFlamePosition() {
    final origin = game.worldOriginOnScreen;

    // Project the 8 corners and find screen bounding rect.
    // For a box with top-face center at (worldPos.x, topY, worldPos.z):
    final hx = sizeX / 2;
    final hz = sizeZ / 2;

    final corners = <Vector2>[
      IsoProjection.projectXYZ(worldPos.x - hx, topY,    worldPos.z - hz, screenOrigin: origin),
      IsoProjection.projectXYZ(worldPos.x + hx, topY,    worldPos.z - hz, screenOrigin: origin),
      IsoProjection.projectXYZ(worldPos.x - hx, topY,    worldPos.z + hz, screenOrigin: origin),
      IsoProjection.projectXYZ(worldPos.x + hx, topY,    worldPos.z + hz, screenOrigin: origin),
      IsoProjection.projectXYZ(worldPos.x - hx, bottomY, worldPos.z - hz, screenOrigin: origin),
      IsoProjection.projectXYZ(worldPos.x + hx, bottomY, worldPos.z - hz, screenOrigin: origin),
      IsoProjection.projectXYZ(worldPos.x - hx, bottomY, worldPos.z + hz, screenOrigin: origin),
      IsoProjection.projectXYZ(worldPos.x + hx, bottomY, worldPos.z + hz, screenOrigin: origin),
    ];

    double minX = corners[0].x, maxX = corners[0].x;
    double minY = corners[0].y, maxY = corners[0].y;
    for (final c in corners.skip(1)) {
      if (c.x < minX) minX = c.x; if (c.x > maxX) maxX = c.x;
      if (c.y < minY) minY = c.y; if (c.y > maxY) maxY = c.y;
    }

    position = Vector2(minX, minY);
    size     = Vector2((maxX - minX).clamp(4, 4000), (maxY - minY).clamp(4, 2000));
  }

  // ── render ────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final origin = game.worldOriginOnScreen;
    final hx = sizeX / 2;
    final hz = sizeZ / 2;

    Vector2 p(double wx, double wy, double wz) =>
        IsoProjection.projectXYZ(wx, wy, wz, screenOrigin: origin) - position;

    final tl  = p(worldPos.x - hx, topY,    worldPos.z - hz);
    final tr  = p(worldPos.x + hx, topY,    worldPos.z - hz);
    final tf  = p(worldPos.x + hx, topY,    worldPos.z + hz);
    final tfl = p(worldPos.x - hx, topY,    worldPos.z + hz);
    final bl  = p(worldPos.x - hx, bottomY, worldPos.z - hz);
    final br  = p(worldPos.x + hx, bottomY, worldPos.z - hz);
    final bf  = p(worldPos.x + hx, bottomY, worldPos.z + hz);

    final topPath = Path()
      ..moveTo(tl.x, tl.y) ..lineTo(tr.x, tr.y)
      ..lineTo(tf.x, tf.y) ..lineTo(tfl.x, tfl.y) ..close();
    final frontPath = Path()
      ..moveTo(tl.x, tl.y) ..lineTo(tr.x, tr.y)
      ..lineTo(br.x, br.y) ..lineTo(bl.x, bl.y) ..close();
    final rightPath = Path()
      ..moveTo(tr.x, tr.y) ..lineTo(tf.x, tf.y)
      ..lineTo(bf.x, bf.y) ..lineTo(br.x, br.y) ..close();

    if (_loaded && _tileTexture != null) {
      final img = _tileTexture!;
      final tw  = img.width.toDouble();
      final th  = img.height.toDouble();
      final src = Rect.fromLTWH(0, 0, tw, th);

      // Tile across top face: map world sizeX × sizeZ using screen bounds.
      _drawTiledFace(canvas, topPath, img, src,
          _bounds(tl, tf), Colors.transparent);

      // Front face: tiled with dark overlay.
      _drawTiledFace(canvas, frontPath, img, src,
          _bounds(tl, br), Colors.black.withOpacity(0.38));

      // Right face: tiled with darker overlay.
      _drawTiledFace(canvas, rightPath, img, src,
          _bounds(tr, bf), Colors.black.withOpacity(0.55));
    } else {
      // Colour fallback.
      canvas.drawPath(rightPath,  Paint()..color = sideColor);
      canvas.drawPath(frontPath,  Paint()..color = frontColor);
      canvas.drawPath(topPath,    Paint()..color = topColor);
    }

    // ── Edge outlines ─────────────────────────────────────────────────────
    final edgePaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(topPath,   edgePaint);
    canvas.drawPath(frontPath, edgePaint);
    canvas.drawPath(rightPath, edgePaint);
    canvas.drawLine(Offset(tf.x, tf.y), Offset(bf.x, bf.y), edgePaint);
    canvas.drawLine(Offset(bl.x, bl.y), Offset(br.x, br.y), edgePaint);
  }

  /// Clip to [facePath], tile [img] filling [bounds], then overlay [shade].
  void _drawTiledFace(
      Canvas canvas, Path facePath, ui.Image img, Rect src,
      Rect bounds, Color shade) {
    canvas.save();
    canvas.clipPath(facePath);

    final tw = src.width;
    final th = src.height;
    final paint = Paint();

    final startX = (bounds.left / tw).floor() * tw;
    final startY = (bounds.top  / th).floor() * th;

    for (double y = startY; y < bounds.bottom + th; y += th) {
      for (double x = startX; x < bounds.right + tw; x += tw) {
        canvas.drawImageRect(img, src, Rect.fromLTWH(x, y, tw, th), paint);
      }
    }

    // Lighting overlay (darken front/side faces).
    if (shade.opacity > 0.01) {
      canvas.drawPath(facePath, Paint()..color = shade);
    }

    canvas.restore();
  }
}

Rect _bounds(Vector2 a, Vector2 b) => Rect.fromLTRB(
  a.x < b.x ? a.x : b.x,
  a.y < b.y ? a.y : b.y,
  a.x > b.x ? a.x : b.x,
  a.y > b.y ? a.y : b.y,
);

// ── Infinite ground slab ──────────────────────────────────────────────────────

/// Infinite flat ground rendered as a receding plane, tiled with ground_tile.png.
class InfiniteGround3D extends PositionComponent
    with HasGameReference<ActionGame3D> {

  static const double _halfExtent = 6000.0;

  ui.Image? _tileImg;

  InfiniteGround3D() : super(
    position: Vector2(-8000, -2000),
    size: Vector2(16000, 8000),
    priority: -1000,
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final name in ['ground_tile.png', 'ground.png']) {
      try { _tileImg = await game.images.load(name); break; } catch (_) {}
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final pp     = game.character.worldPos;
    final origin = game.worldOriginOnScreen;
    final sc     = IsoProjection.projectXYZ(pp.x, 0, pp.z, screenOrigin: origin);
    position = sc - Vector2(8000, 4000);
  }

  @override
  void render(Canvas canvas) {
    final origin = game.worldOriginOnScreen;
    final pp     = game.character.worldPos;
    final ext    = _halfExtent;
    final gy     = GameConfig3D.infiniteGroundY;

    Vector2 proj(double wx, double wz) =>
        IsoProjection.projectXYZ(wx, gy, wz, screenOrigin: origin) - position;

    final nw = proj(pp.x - ext, pp.z - ext);
    final ne = proj(pp.x + ext, pp.z - ext);
    final se = proj(pp.x + ext, pp.z + ext);
    final sw = proj(pp.x - ext, pp.z + ext);

    final groundPath = Path()
      ..moveTo(nw.x, nw.y) ..lineTo(ne.x, ne.y)
      ..lineTo(se.x, se.y) ..lineTo(sw.x, sw.y) ..close();

    canvas.save();
    canvas.clipPath(groundPath);

    if (_tileImg != null) {
      final img   = _tileImg!;
      final tw    = img.width.toDouble();
      final th    = img.height.toDouble();
      final src   = Rect.fromLTWH(0, 0, tw, th);
      final paint = Paint();

      final xs = [nw.x, ne.x, se.x, sw.x];
      final ys = [nw.y, ne.y, se.y, sw.y];
      final minX = xs.reduce((a, b) => a < b ? a : b);
      final minY = ys.reduce((a, b) => a < b ? a : b);
      final maxX = xs.reduce((a, b) => a > b ? a : b);
      final maxY = ys.reduce((a, b) => a > b ? a : b);

      for (double y = (minY / th).floor() * th; y < maxY + th; y += th) {
        for (double x = (minX / tw).floor() * tw; x < maxX + tw; x += tw) {
          canvas.drawImageRect(img, src, Rect.fromLTWH(x, y, tw, th), paint);
        }
      }
    } else {
      canvas.drawPath(groundPath, Paint()..color = const Color(0xFF1e3a1e));
    }

    canvas.restore();

    // ── Horizon fog ───────────────────────────────────────────────────────
    final fogY = nw.y;
    canvas.drawRect(
      Rect.fromLTWH(-8000, fogY - 80, 16000, 320),
      Paint()..shader = ui.Gradient.linear(
        Offset(0, fogY - 80), Offset(0, fogY + 240),
        [const Color(0x881a1a2e), Colors.transparent],
      ),
    );
  }
}