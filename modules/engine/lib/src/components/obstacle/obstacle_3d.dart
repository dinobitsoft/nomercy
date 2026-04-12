// modules/engine/lib/src/components/obstacle/obstacle_3d.dart

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A solid 3D obstacle — all 6 faces are collidable.
///
/// Collision contract:
///   • Top face  → character lands and stands on it (same as a platform).
///   • Side faces (XZ) → character is pushed back; velocity component zeroed.
///
/// Characters must jump *over* or walk *around* an obstacle; they can never
/// pass through it.  The collision resolution lives in
/// [GameCharacter3D._applyPhysics3D].
///
/// Supported [obstacleType] values (affects colour + decoration):
///   'crate' | 'barrel' | 'wall' | 'stone_wall'
class Obstacle3D extends PositionComponent with HasGameReference<ActionGame3D> {

  // ── 3D world geometry ────────────────────────────────────────────────────

  /// Centre of the *top face* in world space (same convention as GamePlatform3D).
  WorldPos worldPos;

  final double sizeX;       // width  (X axis)
  final double sizeY;       // height (Y axis) — visual block height
  final double sizeZ;       // depth  (Z axis)

  final String obstacleType;

  // ── visual ───────────────────────────────────────────────────────────────

  Color topColor   = const Color(0xFFd4a843);
  Color sideColor  = const Color(0xFF6b3a0c);
  Color frontColor = const Color(0xFF8b5016);

  bool      _loaded = false;
  ui.Image? _tex;

  Obstacle3D({
    required this.worldPos,
    required this.sizeX,
    required this.sizeY,
    required this.sizeZ,
    required this.obstacleType,
    int priority = 0,
  }) : super(anchor: Anchor.topLeft, priority: priority);

  // ── AABB helpers ─────────────────────────────────────────────────────────

  double get topY    => worldPos.y;
  double get bottomY => worldPos.y - sizeY;

  AABB3D get aabb => AABB3D(
    minX: worldPos.x - sizeX / 2,  maxX: worldPos.x + sizeX / 2,
    minY: bottomY,                  maxY: topY,
    minZ: worldPos.z - sizeZ / 2,  maxZ: worldPos.z + sizeZ / 2,
  );

  /// True when character XZ footprint overlaps this obstacle.
  bool footprintOverlaps(AABB3D charAabb) => aabb.overlapsXZ(charAabb);

  // ── depth sort ────────────────────────────────────────────────────────────

  void updateDepthPriority() {
    // +10 offset so obstacles sort slightly in front of same-Z platforms.
    priority = IsoProjection.depthPriority(worldPos) + 10;
  }

  // ── onLoad ────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _applyColors();
    // Try to load a texture matching the obstacle type; fall back to brick.
    for (final name in [
      '${obstacleType}_tile.png',
      '$obstacleType.png',
      'brick_tile.png',
      'brick.png',
    ]) {
      try {
        _tex    = await game.images.load(name);
        _loaded = true;
        break;
      } catch (_) {}
    }
    _syncFlamePosition();
  }

  void _applyColors() {
    switch (obstacleType) {
      case 'crate':
        topColor   = const Color(0xFFd4a843);
        frontColor = const Color(0xFF8b5a16);
        sideColor  = const Color(0xFF6b3a0c);
      case 'barrel':
        topColor   = const Color(0xFF8a7a6a);
        frontColor = const Color(0xFF4a3828);
        sideColor  = const Color(0xFF3a2818);
      case 'wall':
      case 'stone_wall':
        topColor   = const Color(0xFF909090);
        frontColor = const Color(0xFF484848);
        sideColor  = const Color(0xFF303030);
      default:
        topColor   = const Color(0xFFc08860);
        frontColor = const Color(0xFF804830);
        sideColor  = const Color(0xFF603820);
    }
  }

  // ── update ────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _syncFlamePosition();
    updateDepthPriority();
  }

  void _syncFlamePosition() {
    final origin = game.worldOriginOnScreen;
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
      if (c.x < minX) minX = c.x;
      if (c.x > maxX) maxX = c.x;
      if (c.y < minY) minY = c.y;
      if (c.y > maxY) maxY = c.y;
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

    // All 8 projected corners.
    // Naming: t/b = top/bottom, l/r = -x/+x, n/f = near(-z)/far(+z)
    final tln = p(worldPos.x - hx, topY,    worldPos.z - hz);
    final trn = p(worldPos.x + hx, topY,    worldPos.z - hz);
    final trf = p(worldPos.x + hx, topY,    worldPos.z + hz);
    final tlf = p(worldPos.x - hx, topY,    worldPos.z + hz);
    final bln = p(worldPos.x - hx, bottomY, worldPos.z - hz);
    final brn = p(worldPos.x + hx, bottomY, worldPos.z - hz);
    final brf = p(worldPos.x + hx, bottomY, worldPos.z + hz);
    final blf = p(worldPos.x - hx, bottomY, worldPos.z + hz); // ← was missing

    // Face paths.
    final topPath = Path()
      ..moveTo(tln.x, tln.y) ..lineTo(trn.x, trn.y)
      ..lineTo(trf.x, trf.y) ..lineTo(tlf.x, tlf.y) ..close();

    // Front = near-Z face (faces player approaching from -Z).
    final frontPath = Path()
      ..moveTo(tln.x, tln.y) ..lineTo(trn.x, trn.y)
      ..lineTo(brn.x, brn.y) ..lineTo(bln.x, bln.y) ..close();

    // Right = +X face.
    final rightPath = Path()
      ..moveTo(trn.x, trn.y) ..lineTo(trf.x, trf.y)
      ..lineTo(brf.x, brf.y) ..lineTo(brn.x, brn.y) ..close();

    // Left = -X face (darkest; shares tln-bln edge with front face).
    final leftPath = Path()
      ..moveTo(tln.x, tln.y) ..lineTo(tlf.x, tlf.y)
      ..lineTo(blf.x, blf.y) ..lineTo(bln.x, bln.y) ..close();

    // Draw back-to-front: left → front → right → top.
    if (_loaded && _tex != null) {
      final img = _tex!;
      final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      _drawTiledFace(canvas, leftPath,  img, src, _obstacleBounds(tlf, bln), Colors.black.withOpacity(0.70));
      _drawTiledFace(canvas, frontPath, img, src, _obstacleBounds(tln, brn), Colors.black.withOpacity(0.55));
      _drawTiledFace(canvas, rightPath, img, src, _obstacleBounds(trn, brf), Colors.black.withOpacity(0.35));
      _drawTiledFace(canvas, topPath,   img, src, _obstacleBounds(tlf, trn), Colors.black.withOpacity(0.10));
    } else {
      final leftDark = Color.lerp(frontColor, Colors.black, 0.45)!;
      canvas.drawPath(leftPath,  Paint()..color = leftDark);
      canvas.drawPath(frontPath, Paint()..color = frontColor);
      canvas.drawPath(rightPath, Paint()..color = sideColor);
      canvas.drawPath(topPath,   Paint()..color = topColor);
    }

    // Type-specific surface decoration (front face only).
    _drawDecoration(canvas, tln, trn, trf, tlf, bln, brn);

    // Complete edge outlines — all 12 box edges.
    final edgePaint = Paint()
      ..color       = Colors.black.withOpacity(0.75)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(topPath,   edgePaint);
    canvas.drawPath(frontPath, edgePaint);
    canvas.drawPath(rightPath, edgePaint);
    canvas.drawPath(leftPath,  edgePaint);
    // Remaining edges not covered by the face outlines above:
    canvas.drawLine(Offset(trf.x, trf.y), Offset(brf.x, brf.y), edgePaint); // far-right vertical
    canvas.drawLine(Offset(bln.x, bln.y), Offset(brn.x, brn.y), edgePaint); // front bottom
    canvas.drawLine(Offset(brn.x, brn.y), Offset(brf.x, brf.y), edgePaint); // right bottom
    canvas.drawLine(Offset(brf.x, brf.y), Offset(blf.x, blf.y), edgePaint); // far bottom
    canvas.drawLine(Offset(bln.x, bln.y), Offset(blf.x, blf.y), edgePaint); // left bottom
  }

  // ── decoration per obstacle type ─────────────────────────────────────────

  void _drawDecoration(Canvas canvas,
      Vector2 tln, Vector2 trn, Vector2 trf, Vector2 tlf,
      Vector2 bln, Vector2 brn) {
    switch (obstacleType) {
      case 'crate':       _drawCrateStraps(canvas, tln, trn, brn, bln);
      case 'barrel':      _drawBarrelRings(canvas, tln, trn, brn, bln);
      case 'wall':
      case 'stone_wall':  _drawMortarLines(canvas, tln, trn, brn, bln);
      default:            break;
    }
  }

  /// Wooden crate: cross-strap on the front face.
  void _drawCrateStraps(Canvas canvas,
      Vector2 tl, Vector2 tr, Vector2 br, Vector2 bl) {
    final strap = Paint()
      ..color       = const Color(0xFF3b1e08).withOpacity(0.70)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap   = StrokeCap.round;
    // Vertical centre strap
    canvas.drawLine(
      Offset((tl.x + tr.x) / 2, (tl.y + tr.y) / 2),
      Offset((bl.x + br.x) / 2, (bl.y + br.y) / 2),
      strap,
    );
    // Horizontal mid-height strap
    canvas.drawLine(
      Offset(_lerp1(tl.x, bl.x, 0.5), _lerp1(tl.y, bl.y, 0.5)),
      Offset(_lerp1(tr.x, br.x, 0.5), _lerp1(tr.y, br.y, 0.5)),
      strap,
    );
  }

  /// Metal barrel: two horizontal rings at 20% and 80% height.
  void _drawBarrelRings(Canvas canvas,
      Vector2 tl, Vector2 tr, Vector2 br, Vector2 bl) {
    final ring = Paint()
      ..color       = Colors.grey.shade600.withOpacity(0.85)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap   = StrokeCap.butt;
    for (final t in [0.22, 0.78]) {
      canvas.drawLine(
        Offset(_lerp1(tl.x, bl.x, t), _lerp1(tl.y, bl.y, t)),
        Offset(_lerp1(tr.x, br.x, t), _lerp1(tr.y, br.y, t)),
        ring,
      );
    }
  }

  /// Stone wall: horizontal mortar joints at 33% and 66% height.
  void _drawMortarLines(Canvas canvas,
      Vector2 tl, Vector2 tr, Vector2 br, Vector2 bl) {
    final mortar = Paint()
      ..color       = Colors.black.withOpacity(0.40)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    for (final t in [0.33, 0.66]) {
      canvas.drawLine(
        Offset(_lerp1(tl.x, bl.x, t), _lerp1(tl.y, bl.y, t)),
        Offset(_lerp1(tr.x, br.x, t), _lerp1(tr.y, br.y, t)),
        mortar,
      );
    }
    // Vertical half-brick offset at mid row
    canvas.drawLine(
      Offset(_lerp1(tl.x, tr.x, 0.5), _lerp1(tl.y, tr.y, 0.5)),
      Offset(_lerp1(
          _lerp1(tl.x, bl.x, 0.33), _lerp1(tr.x, br.x, 0.33), 0.5),
          _lerp1(
          _lerp1(tl.y, bl.y, 0.33), _lerp1(tr.y, br.y, 0.33), 0.5)),
      mortar,
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  double _lerp1(double a, double b, double t) => a + (b - a) * t;

  void _drawTiledFace(Canvas canvas, Path facePath, ui.Image img, Rect src,
      Rect bounds, Color shade) {
    canvas.save();
    canvas.clipPath(facePath);
    final tw = src.width;
    final th = src.height;
    final paint = Paint();
    final startX = (bounds.left  / tw).floor() * tw;
    final startY = (bounds.top   / th).floor() * th;
    for (double y = startY; y < bounds.bottom + th; y += th) {
      for (double x = startX; x < bounds.right + tw; x += tw) {
        canvas.drawImageRect(img, src, Rect.fromLTWH(x, y, tw, th), paint);
      }
    }
    if (shade.opacity > 0.01) {
      canvas.drawPath(facePath, Paint()..color = shade);
    }
    canvas.restore();
  }
}

// ── Local helper (file-scoped) ────────────────────────────────────────────────

Rect _obstacleBounds(Vector2 a, Vector2 b) => Rect.fromLTRB(
  math.min(a.x, b.x), math.min(a.y, b.y),
  math.max(a.x, b.x), math.max(a.y, b.y),
);
