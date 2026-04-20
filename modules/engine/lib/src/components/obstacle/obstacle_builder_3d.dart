// modules/engine/lib/src/components/obstacle/obstacle_builder_3d.dart

import 'package:core/core.dart';

import 'obstacle_3d.dart';

/// Spec for a single box — position + dimensions + type.
/// [pos.y] is the **top face** Y (same convention as [Obstacle3D.worldPos]).
typedef _BoxSpec = ({WorldPos pos, double sx, double sy, double sz, String type});

/// Factory that produces groups of [Obstacle3D] forming complex 3D structures.
///
/// Every structure sits on [groundY] (default = [GameConfig3D.groundSurfaceY]).
/// All returned obstacles must be added to the game world and registered in
/// [ActionGame3D.obstacles3D] by the caller.
///
/// ## Available structures
///
/// | Method             | Description                                       |
/// |--------------------|---------------------------------------------------|
/// | [stairway]         | N ascending steps — walkable via step-up mechanic |
/// | [elevatedPlatform] | Raised slab supported by side columns             |
/// | [archway]          | Two pillars + lintel — run underneath              |
/// | [zigzagRamp]       | Alternating left/right steps forming a Z-path     |
/// | [pyramid]          | Square pyramid of stacked layers                  |
abstract final class ObstacleBuilder3D {

  // ── Stairway ──────────────────────────────────────────────────────────────

  /// A stairway of [steps] ascending steps running in the +Z direction.
  ///
  /// Each step is [stepHeight] world-units taller than the previous.
  /// With the default step height of 60 units the step-up mechanic
  /// ([GameConfig3D.stepUpMax] = 75) allows characters to walk up without
  /// jumping.
  ///
  /// [origin] = world position of the **bottom-left front corner** of step 1.
  static List<Obstacle3D> stairway({
    required WorldPos origin,
    int    steps      = 5,
    double stepWidth  = 180.0,
    double stepHeight = 60.0,
    double stepDepth  = 90.0,
    String type       = 'stone',
  }) {
    final specs = <_BoxSpec>[];
    for (int i = 0; i < steps; i++) {
      final h    = stepHeight * (i + 1);           // cumulative height
      final topY = origin.y + h;
      final posZ = origin.z + i * stepDepth + stepDepth / 2;
      specs.add((
        pos: WorldPos(origin.x, topY, posZ),
        sx: stepWidth,
        sy: h,
        sz: stepDepth,
        type: type,
      ));
    }
    return _build(specs);
  }

  // ── Elevated Platform ─────────────────────────────────────────────────────

  /// A wide raised slab sitting on two flanking columns.
  ///
  /// The slab top is at [platformHeight] above [groundY]. Characters must
  /// climb the side stairways or jump to reach the platform.
  ///
  /// [origin] = centre of the structure at ground level.
  static List<Obstacle3D> elevatedPlatform({
    required WorldPos origin,
    double platformHeight = 240.0,
    double platformWidth  = 600.0,
    double platformDepth  = 200.0,
    double slabThickness  = 60.0,
    double columnWidth    = 100.0,
    double groundY        = GameConfig3D.groundSurfaceY,
    String type           = 'stone',
  }) {
    final columnH  = platformHeight;
    final slabTopY = groundY + platformHeight + slabThickness;

    return _build([
      // Left column
      (
        pos: WorldPos(origin.x - platformWidth / 2 + columnWidth / 2,
                      groundY + columnH, origin.z),
        sx: columnWidth, sy: columnH, sz: columnWidth, type: type,
      ),
      // Right column
      (
        pos: WorldPos(origin.x + platformWidth / 2 - columnWidth / 2,
                      groundY + columnH, origin.z),
        sx: columnWidth, sy: columnH, sz: columnWidth, type: type,
      ),
      // Slab
      (
        pos: WorldPos(origin.x, slabTopY, origin.z),
        sx: platformWidth, sy: slabThickness, sz: platformDepth, type: type,
      ),
    ]);
  }

  // ── Archway ───────────────────────────────────────────────────────────────

  /// Two tall pillars connected by a lintel overhead.
  ///
  /// Characters run *through* the gap between pillars.  The opening width
  /// should be wider than [GameConfig3D.characterSizeX] × 2 so bots can
  /// navigate it freely (default 280 ≈ 3.5 × characterSizeX).
  ///
  /// [origin] = centre of the archway at ground level.
  static List<Obstacle3D> archway({
    required WorldPos origin,
    double openingWidth  = 280.0,
    double pillarWidth   = 80.0,
    double pillarHeight  = 280.0,
    double pillarDepth   = 80.0,
    double lintelThick   = 60.0,
    double groundY       = GameConfig3D.groundSurfaceY,
    String type          = 'brick',
  }) {
    final totalWidth  = openingWidth + pillarWidth * 2;
    final lintelTopY  = groundY + pillarHeight + lintelThick;

    return _build([
      // Left pillar
      (
        pos: WorldPos(origin.x - openingWidth / 2 - pillarWidth / 2,
                      groundY + pillarHeight, origin.z),
        sx: pillarWidth, sy: pillarHeight, sz: pillarDepth, type: type,
      ),
      // Right pillar
      (
        pos: WorldPos(origin.x + openingWidth / 2 + pillarWidth / 2,
                      groundY + pillarHeight, origin.z),
        sx: pillarWidth, sy: pillarHeight, sz: pillarDepth, type: type,
      ),
      // Lintel
      (
        pos: WorldPos(origin.x, lintelTopY, origin.z),
        sx: totalWidth, sy: lintelThick, sz: pillarDepth, type: type,
      ),
    ]);
  }

  // ── Zigzag Ramp ───────────────────────────────────────────────────────────

  /// A series of steps that alternate left and right, forming a zig-zag path
  /// upward.  Each level is [levelHeight] above the previous.
  ///
  /// [origin] = front-centre at ground level.
  static List<Obstacle3D> zigzagRamp({
    required WorldPos origin,
    int    levels       = 4,
    double levelHeight  = 60.0,
    double blockWidth   = 260.0,
    double blockDepth   = 140.0,
    double groundY      = GameConfig3D.groundSurfaceY,
    String type         = 'brick',
  }) {
    final specs = <_BoxSpec>[];
    for (int i = 0; i < levels; i++) {
      final h    = levelHeight * (i + 1);
      final topY = groundY + h;
      final posZ = origin.z + i * blockDepth + blockDepth / 2;
      // Alternate between left (-X) and right (+X) offset.
      final xOff = (i.isEven ? -1 : 1) * blockWidth * 0.30;
      specs.add((
        pos: WorldPos(origin.x + xOff, topY, posZ),
        sx: blockWidth, sy: h, sz: blockDepth, type: type,
      ));
    }
    return _build(specs);
  }

  // ── Pyramid ───────────────────────────────────────────────────────────────

  /// A stepped square pyramid.  [layers] stacked rings, each [layerHeight]
  /// tall and [stepInset] narrower per side.
  ///
  /// [origin] = centre at ground level.
  static List<Obstacle3D> pyramid({
    required WorldPos origin,
    int    layers      = 4,
    double baseWidth   = 480.0,
    double layerHeight = 60.0,
    double stepInset   = 60.0,
    double groundY     = GameConfig3D.groundSurfaceY,
    String type        = 'stone',
  }) {
    final specs = <_BoxSpec>[];
    for (int i = 0; i < layers; i++) {
      final w    = baseWidth - i * stepInset * 2;
      if (w <= 0) break;
      final h    = layerHeight * (i + 1);
      final topY = groundY + h;
      specs.add((
        pos: WorldPos(origin.x, topY, origin.z),
        sx: w, sy: h, sz: w, type: type,
      ));
    }
    return _build(specs);
  }

  // ── Internal builder ──────────────────────────────────────────────────────

  static List<Obstacle3D> _build(List<_BoxSpec> specs) {
    return specs.map((s) => Obstacle3D(
      worldPos:     s.pos,
      sizeX:        s.sx,
      sizeY:        s.sy,
      sizeZ:        s.sz,
      obstacleType: s.type,
    )).toList();
  }
}
