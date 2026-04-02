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
  ui.Image? _topTexture;
  ui.Image? _sideTexture;

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

    try {
      _topTexture  = await game.images.load('${platformType}_top.png');
      _sideTexture = await game.images.load('${platformType}_side.png');
      _loaded = true;
    } catch (_) {
      // Flat colour fallback — no-op.
    }

    _syncFlamePosition();
  }

  void _applyPlatformColors() {
    switch (platformType) {
      case 'ground':
        topColor   = const Color(0xFF5a8a4a);
        sideColor  = const Color(0xFF3a5a2a);
        frontColor = const Color(0xFF4a7a3a);
      case 'brick':
        topColor   = const Color(0xFFa07050);
        sideColor  = const Color(0xFF704830);
        frontColor = const Color(0xFF885840);
      case 'stone':
        topColor   = const Color(0xFF7a7a8a);
        sideColor  = const Color(0xFF5a5a6a);
        frontColor = const Color(0xFF6a6a7a);
      case 'ice':
        topColor   = const Color(0xFFa0d0f0);
        sideColor  = const Color(0xFF70a0c0);
        frontColor = const Color(0xFF88b8d8);
      default:
        topColor   = const Color(0xFF6060a0);
        sideColor  = const Color(0xFF404070);
        frontColor = const Color(0xFF505090);
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

    // Helper: world → canvas-local (subtracts Flame position because Flame
    // already translated the canvas to this component's top-left corner).
    Vector2 p(double wx, double wy, double wz) {
      final s = IsoProjection.projectXYZ(wx, wy, wz, screenOrigin: origin);
      return s - position; // local canvas coords
    }

    // ── Top face (visible from above) ──────────────────────────────────────
    final topPath = Path()
      ..moveTo(p(worldPos.x - hx, topY, worldPos.z - hz).x, p(worldPos.x - hx, topY, worldPos.z - hz).y)
      ..lineTo(p(worldPos.x + hx, topY, worldPos.z - hz).x, p(worldPos.x + hx, topY, worldPos.z - hz).y)
      ..lineTo(p(worldPos.x + hx, topY, worldPos.z + hz).x, p(worldPos.x + hx, topY, worldPos.z + hz).y)
      ..lineTo(p(worldPos.x - hx, topY, worldPos.z + hz).x, p(worldPos.x - hx, topY, worldPos.z + hz).y)
      ..close();

    if (_loaded && _topTexture != null) {
      // TODO: apply image shader when assets are ready.
      canvas.drawPath(topPath, Paint()..color = topColor);
    } else {
      canvas.drawPath(topPath, Paint()..color = topColor);
    }

    // Top face edge highlight
    canvas.drawPath(topPath,
        Paint()..color = Colors.white.withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // ── Front face (near camera: -Z side) ─────────────────────────────────
    final frontPath = Path()
      ..moveTo(p(worldPos.x - hx, topY,    worldPos.z - hz).x, p(worldPos.x - hx, topY,    worldPos.z - hz).y)
      ..lineTo(p(worldPos.x + hx, topY,    worldPos.z - hz).x, p(worldPos.x + hx, topY,    worldPos.z - hz).y)
      ..lineTo(p(worldPos.x + hx, bottomY, worldPos.z - hz).x, p(worldPos.x + hx, bottomY, worldPos.z - hz).y)
      ..lineTo(p(worldPos.x - hx, bottomY, worldPos.z - hz).x, p(worldPos.x - hx, bottomY, worldPos.z - hz).y)
      ..close();
    canvas.drawPath(frontPath, Paint()..color = frontColor);

    // ── Right face (+X side) ───────────────────────────────────────────────
    final rightPath = Path()
      ..moveTo(p(worldPos.x + hx, topY,    worldPos.z - hz).x, p(worldPos.x + hx, topY,    worldPos.z - hz).y)
      ..lineTo(p(worldPos.x + hx, topY,    worldPos.z + hz).x, p(worldPos.x + hx, topY,    worldPos.z + hz).y)
      ..lineTo(p(worldPos.x + hx, bottomY, worldPos.z + hz).x, p(worldPos.x + hx, bottomY, worldPos.z + hz).y)
      ..lineTo(p(worldPos.x + hx, bottomY, worldPos.z - hz).x, p(worldPos.x + hx, bottomY, worldPos.z - hz).y)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = sideColor);
  }
}

// ── Infinite ground slab ──────────────────────────────────────────────────────

/// Infinite flat ground rendered as a receding plane.
/// Stays centred on the player's X and Z positions.
class InfiniteGround3D extends PositionComponent
    with HasGameReference<ActionGame3D> {

  static const double _halfExtent = 6000.0;  // visual half-width in X and Z

  InfiniteGround3D() : super(
    position: Vector2(-8000, -2000),
    size: Vector2(16000, 8000),
    priority: -1000,
  );

  @override
  void update(double dt) {
    super.update(dt);
    // Recentre around player so it never ends.
    final pp = game.character.worldPos;
    final origin = game.worldOriginOnScreen;
    // Move Flame bounding box so culling doesn't remove us.
    final screenCenter = IsoProjection.projectXYZ(pp.x, 0, pp.z, screenOrigin: origin);
    position = screenCenter - Vector2(8000, 4000);
  }

  @override
  void render(Canvas canvas) {
    final origin  = game.worldOriginOnScreen;
    final pp      = game.character.worldPos;
    final ext     = _halfExtent;

    Vector2 proj(double wx, double wz) =>
        IsoProjection.projectXYZ(wx, GameConfig3D.infiniteGroundY, wz,
            screenOrigin: origin) - position;

    // Ground top face (very large quad centred on player).
    final path = Path()
      ..moveTo(proj(pp.x - ext, pp.z - ext).x, proj(pp.x - ext, pp.z - ext).y)
      ..lineTo(proj(pp.x + ext, pp.z - ext).x, proj(pp.x + ext, pp.z - ext).y)
      ..lineTo(proj(pp.x + ext, pp.z + ext).x, proj(pp.x + ext, pp.z + ext).y)
      ..lineTo(proj(pp.x - ext, pp.z + ext).x, proj(pp.x - ext, pp.z + ext).y)
      ..close();

    // Subtle grid pattern via shader-less approach: solid fill + grid lines.
    canvas.drawPath(path, Paint()..color = const Color(0xFF2a4a2a));

    // Horizon fog gradient overlay (optional visual polish).
    final rect = Rect.fromLTWH(position.x - 8000, position.y - 4000, 16000, 8000);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, position.y),
          Offset(0, position.y - 2000),
          [Colors.transparent, const Color(0x441a1a2e)],
        ),
    );
  }
}