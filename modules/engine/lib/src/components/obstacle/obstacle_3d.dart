// modules/engine/lib/src/components/obstacle/obstacle_3d.dart

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A solid 3D obstacle box rendered with flat isometric shading.
///
/// No sprites or textures — three visible faces are filled with opaque colours
/// derived from a single [baseColor], giving a clean Minecraft-style look.
///
/// Collision contract (physics in [GameCharacter3D._applyPhysics3D]):
///   • Top face  → character lands/stands (same as a platform).
///   • Side faces (XZ) → lateral push-back; character must jump over or
///     climb via the step-up mechanic for steps ≤ [GameConfig3D.stepUpMax].
///
/// Supported [obstacleType] values (affects colour):
///   'brick' | 'stone' | 'wood' | 'ice' | 'dirt' | 'ground'
///   Any unknown type uses a neutral brown.
class Obstacle3D extends PositionComponent with HasGameReference<ActionGame3D> {

  // ── 3D world geometry ─────────────────────────────────────────────────────

  /// Centre of the *top face* in world space.
  WorldPos worldPos;

  final double sizeX;   // width  (X axis)
  final double sizeY;   // height (Y axis)
  final double sizeZ;   // depth  (Z axis)

  final String obstacleType;

  // ── derived face colours (set in [_applyColors]) ──────────────────────────

  late Color _topColor;
  late Color _frontColor;   // near-Z face, faces camera
  late Color _rightColor;   // +X side
  late Color _leftColor;    // −X side (darkest)

  Obstacle3D({
    required this.worldPos,
    required this.sizeX,
    required this.sizeY,
    required this.sizeZ,
    required this.obstacleType,
    int priority = 0,
  }) : super(anchor: Anchor.topLeft, priority: priority) {
    _applyColors();
  }

  // ── AABB helpers ──────────────────────────────────────────────────────────

  double get topY    => worldPos.y;
  double get bottomY => worldPos.y - sizeY;

  AABB3D get aabb => AABB3D(
    minX: worldPos.x - sizeX / 2,  maxX: worldPos.x + sizeX / 2,
    minY: bottomY,                  maxY: topY,
    minZ: worldPos.z - sizeZ / 2,  maxZ: worldPos.z + sizeZ / 2,
  );

  bool footprintOverlaps(AABB3D charAabb) => aabb.overlapsXZ(charAabb);

  // ── colour setup ──────────────────────────────────────────────────────────

  void _applyColors() {
    final base = _baseColor(obstacleType);
    _topColor   = _lighten(base, 0.28);
    _frontColor = base;
    _rightColor = _darken(base, 0.20);
    _leftColor  = _darken(base, 0.40);
  }

  static Color _baseColor(String type) {
    switch (type) {
      case 'brick':   return const Color(0xFFb84030);
      case 'stone':   return const Color(0xFF787878);
      case 'wood':    return const Color(0xFFc0883a);
      case 'ice':     return const Color(0xFF68b0cc);
      case 'dirt':    return const Color(0xFF8a6438);
      case 'ground':  return const Color(0xFF5a8a3a);
      case 'metal':   return const Color(0xFF607080);
      case 'sand':    return const Color(0xFFcab060);
      default:        return const Color(0xFF9a7050);
    }
  }

  static Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;
  static Color _darken (Color c, double t) => Color.lerp(c, Colors.black, t)!;

  // ── depth sort ────────────────────────────────────────────────────────────

  void updateDepthPriority() {
    priority = IsoProjection.depthPriority(worldPos) + 10;
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _syncFlamePosition();
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

    // Compute the screen-space bounding box of all 8 projected corners.
    final corners = [
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

    // Project a world corner to local canvas space (offset by component position).
    Vector2 p(double wx, double wy, double wz) =>
        IsoProjection.projectXYZ(wx, wy, wz, screenOrigin: origin) - position;

    // All 8 corners. Naming: t/b=top/bottom, l/r=−X/+X, n/f=near(−Z)/far(+Z).
    final tln = p(worldPos.x - hx, topY,    worldPos.z - hz);
    final trn = p(worldPos.x + hx, topY,    worldPos.z - hz);
    final trf = p(worldPos.x + hx, topY,    worldPos.z + hz);
    final tlf = p(worldPos.x - hx, topY,    worldPos.z + hz);
    final bln = p(worldPos.x - hx, bottomY, worldPos.z - hz);
    final brn = p(worldPos.x + hx, bottomY, worldPos.z - hz);
    final brf = p(worldPos.x + hx, bottomY, worldPos.z + hz);
    final blf = p(worldPos.x - hx, bottomY, worldPos.z + hz);

    // Painter's algorithm: back faces first, top last.
    _fillFace(canvas, [tlf, tln, bln, blf], _leftColor);   // −X face (deepest shadow)
    _fillFace(canvas, [tln, trn, brn, bln], _frontColor);  // −Z face (faces camera)
    _fillFace(canvas, [trn, trf, brf, brn], _rightColor);  // +X face
    _fillFace(canvas, [tln, trn, trf, tlf], _topColor);    // top (brightest)

    // Crisp edge outlines on all 12 box edges.
    _drawEdges(canvas, tln, trn, trf, tlf, bln, brn, brf, blf);
  }

  void _fillFace(Canvas canvas, List<Vector2> pts, Color color) {
    final path = Path()..moveTo(pts[0].x, pts[0].y);
    for (int i = 1; i < pts.length; i++) path.lineTo(pts[i].x, pts[i].y);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawEdges(Canvas canvas,
      Vector2 tln, Vector2 trn, Vector2 trf, Vector2 tlf,
      Vector2 bln, Vector2 brn, Vector2 brf, Vector2 blf) {
    final p = Paint()
      ..color       = const Color(0xCC000000)   // solid black, 80 % opacity
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap   = StrokeCap.round;

    void line(Vector2 a, Vector2 b) =>
        canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), p);

    // Top face edges
    line(tln, trn); line(trn, trf); line(trf, tlf); line(tlf, tln);
    // Bottom face edges
    line(bln, brn); line(brn, brf); line(brf, blf); line(blf, bln);
    // Vertical edges
    line(tln, bln); line(trn, brn); line(trf, brf); line(tlf, blf);
  }
}
