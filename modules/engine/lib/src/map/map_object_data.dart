// modules/engine/lib/src/map/map_object_data.dart

/// The geometric shape / structure type of a map object.
///
/// **Single-box shapes** (box, wall, triangle, cone, cylinder) produce one
/// [Obstacle3D].  The object's [MapObjectData.y] is the **floor/bottom** Y
/// of the bounding box; [MapMaker3D] adds [sizeY] to get the top-face Y that
/// [Obstacle3D] expects.
///
/// **Platform** produces one [GamePlatform3D] (top-landing only, no lateral
/// collision).  Same Y convention as single-box shapes.
///
/// **Compound shapes** (stairs, ramp, elevatedPlatform, arch, zigzag, pyramid)
/// are expanded into multiple [Obstacle3D] instances by [ObstacleBuilder3D].
/// [MapObjectData.y] is the **ground level** passed to the builder.
/// Shape-specific parameters live in [MapObjectData.props].
///
/// ### Non-box shape collision note
/// triangle, cone, and cylinder shapes use an axis-aligned box as their
/// physics hull (same as Obstacle3D).  The shape field is preserved in the
/// data format so future renderers can draw the correct geometry.
enum MapObjectShape {
  /// Solid rectangular box.
  box,

  /// Thin vertical wall — same as box but expected to have narrow Z depth.
  wall,

  /// Floating slab — top-landing only, no lateral push-back ([GamePlatform3D]).
  platform,

  /// Ascending stairway along +Z.
  ///
  /// Props: steps(int), stepWidth(double), stepHeight(double), stepDepth(double).
  stairs,

  /// Sloped ramp approximated as dense stairway.
  ///
  /// Props: subdivisions(int) — number of steps used to approximate the slope.
  /// Uses sizeX / sizeY / sizeZ as total bounding dimensions.
  ramp,

  /// Raised horizontal slab supported by two flanking columns.
  ///
  /// Props: platformHeight(double), platformWidth(double), platformDepth(double),
  ///        slabThickness(double), columnWidth(double).
  elevatedPlatform,

  /// Two pillars connected by an overhead lintel.
  ///
  /// Props: openingWidth(double), pillarWidth(double), pillarHeight(double),
  ///        pillarDepth(double), lintelThick(double).
  arch,

  /// Alternating-level zig-zag path ascending in +Z.
  ///
  /// Props: levels(int), levelHeight(double), blockWidth(double), blockDepth(double).
  zigzag,

  /// Stepped square pyramid.
  ///
  /// Props: layers(int), baseWidth(double), layerHeight(double), stepInset(double).
  pyramid,

  /// Triangular prism (wedge). Physics hull is a box.
  triangle,

  /// Cone. Physics hull is a box.
  cone,

  /// Cylinder. Physics hull is a box.
  cylinder,

  /// Player spawn point — designer-only marker; [MapMaker3D] does not create
  /// a game component for this shape.
  spawnPlayer,

  /// Bot spawn point — designer-only marker; [MapMaker3D] does not create
  /// a game component for this shape.
  spawnBot,
}

// ─────────────────────────────────────────────────────────────────────────────

/// Serialisable description of one map object.
///
/// All spatial values are in world units.
///
/// **Y convention** — [y] is always the **floor / bottom-Y** of the structure:
/// * For single-box shapes and platforms: bottom of the bounding box.
/// * For compound shapes: the ground level passed to [ObstacleBuilder3D].
///
/// This differs from [Obstacle3D.worldPos.y] which is the *top* face.
/// [MapMaker3D] handles the conversion automatically.
class MapObjectData {
  final String id;
  final MapObjectShape shape;

  // ── position (floor Y) ─────────────────────────────────────────────────────
  final double x;
  final double y;
  final double z;

  // ── bounding dimensions ───────────────────────────────────────────────────
  /// Width along the X axis.
  final double sizeX;

  /// Height along the Y axis (total from floor to top).
  final double sizeY;

  /// Depth along the Z axis.
  final double sizeZ;

  /// Material / colour type forwarded to [Obstacle3D.obstacleType] or
  /// [GamePlatform3D.platformType].
  ///
  /// Supported values: 'stone' | 'brick' | 'wood' | 'ice' | 'dirt' |
  ///   'ground' | 'metal' | 'sand'.
  final String material;

  /// Shape-specific extra parameters.  See [MapObjectShape] doc comments for
  /// valid keys per shape.
  final Map<String, dynamic> props;

  const MapObjectData({
    required this.id,
    required this.shape,
    required this.x,
    required this.y,
    required this.z,
    this.sizeX = 100.0,
    this.sizeY = 80.0,
    this.sizeZ = 100.0,
    this.material = 'stone',
    this.props = const {},
  });

  factory MapObjectData.fromJson(Map<String, dynamic> json) {
    final pos  = json['position'] as Map<String, dynamic>? ?? {};
    final size = json['size']     as Map<String, dynamic>? ?? {};
    return MapObjectData(
      id:       json['id']       as String,
      shape:    MapObjectShape.values.firstWhere(
                  (s) => s.name == (json['shape'] as String? ?? 'box'),
                  orElse: () => MapObjectShape.box,
                ),
      x:        (pos['x']  as num?)?.toDouble() ?? 0.0,
      y:        (pos['y']  as num?)?.toDouble() ?? 0.0,
      z:        (pos['z']  as num?)?.toDouble() ?? 0.0,
      sizeX:    (size['x'] as num?)?.toDouble() ?? 100.0,
      sizeY:    (size['y'] as num?)?.toDouble() ?? 80.0,
      sizeZ:    (size['z'] as num?)?.toDouble() ?? 100.0,
      material: (json['material'] as String?)  ?? 'stone',
      props:    (json['props']    as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id':       id,
    'shape':    shape.name,
    'position': {'x': x, 'y': y, 'z': z},
    'size':     {'x': sizeX, 'y': sizeY, 'z': sizeZ},
    'material': material,
    if (props.isNotEmpty) 'props': props,
  };

  @override
  String toString() =>
      'MapObjectData(id: $id, shape: ${shape.name}, '
      'pos: ($x, $y, $z), size: ($sizeX × $sizeY × $sizeZ), '
      'material: $material)';
}
