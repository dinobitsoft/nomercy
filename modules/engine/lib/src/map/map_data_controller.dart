// modules/engine/lib/src/map/map_data_controller.dart

import 'map_data_3d.dart';
import 'map_object_data.dart';

// ── Abstract interface ────────────────────────────────────────────────────────

/// Provides [MapData3D] for a given map ID.
///
/// Swap implementations to switch between backend API and local mock:
/// ```dart
/// MapDataController controller = kDebugMode
///     ? MockMapDataController()
///     : HttpMapDataController(baseUrl: 'https://api.example.com');
///
/// final map = await controller.fetchMap('training_ground');
/// ```
abstract class MapDataController {
  /// Fetch map data by [mapId].  Throws [MapNotFoundException] if unknown.
  Future<MapData3D> fetchMap(String mapId);

  /// All map IDs available from this source.
  Future<List<String>> listMapIds();
}

// ── Exception ─────────────────────────────────────────────────────────────────

class MapNotFoundException implements Exception {
  final String mapId;
  const MapNotFoundException(this.mapId);

  @override
  String toString() => 'MapNotFoundException: no map with id "$mapId"';
}

// ── Mock implementation ───────────────────────────────────────────────────────

/// In-memory controller that returns hard-coded [MapData3D] without any network
/// calls.  Simulates a small latency so async code paths are exercised during
/// development and testing.
///
/// Available map IDs:
/// | ID                  | Theme / focus                          |
/// |---------------------|----------------------------------------|
/// | training_ground     | Boxes, walls, stairs, platforms        |
/// | ancient_ruins       | Arches, pyramids, elevated platforms   |
/// | industrial_zone     | Ramps, zigzag, cones, cylinders        |
/// | combat_arena        | Open arena with wall cover             |
class MockMapDataController implements MapDataController {

  /// Simulated round-trip latency.  Set to [Duration.zero] in unit tests.
  final Duration latency;

  const MockMapDataController({this.latency = const Duration(milliseconds: 60)});

  static final Map<String, MapData3D> _maps = {
    'training_ground':  _trainingGround(),
    'ancient_ruins':    _ancientRuins(),
    'industrial_zone':  _industrialZone(),
    'combat_arena':     _combatArena(),
  };

  @override
  Future<MapData3D> fetchMap(String mapId) async {
    if (latency > Duration.zero) await Future.delayed(latency);
    final map = _maps[mapId];
    if (map == null) throw MapNotFoundException(mapId);
    return map;
  }

  @override
  Future<List<String>> listMapIds() async {
    if (latency > Duration.zero) await Future.delayed(latency);
    return _maps.keys.toList();
  }

  // ── Map definitions ────────────────────────────────────────────────────────

  /// Basic geometry: boxes, walls, stairways, floating platforms.
  static MapData3D _trainingGround() => MapData3D(
    id:   'training_ground',
    name: 'Training Ground',
    worldWidth: 2400,
    worldDepth: 3200,
    objects: [
      // ── cover boxes ────────────────────────────────────────────────────────
      MapObjectData(
        id: 'box_left',   shape: MapObjectShape.box,
        x: -400, y: 0, z: 600,
        sizeX: 240, sizeY: 100, sizeZ: 120,
        material: 'stone',
      ),
      MapObjectData(
        id: 'box_right',  shape: MapObjectShape.box,
        x:  400, y: 0, z: 600,
        sizeX: 240, sizeY: 100, sizeZ: 120,
        material: 'stone',
      ),
      MapObjectData(
        id: 'box_centre', shape: MapObjectShape.box,
        x: 0, y: 0, z: 1200,
        sizeX: 180, sizeY: 120, sizeZ: 180,
        material: 'brick',
      ),

      // ── thin walls ─────────────────────────────────────────────────────────
      MapObjectData(
        id: 'wall_a', shape: MapObjectShape.wall,
        x: -600, y: 0, z: 1600,
        sizeX: 320, sizeY: 180, sizeZ: 40,
        material: 'brick',
      ),
      MapObjectData(
        id: 'wall_b', shape: MapObjectShape.wall,
        x:  600, y: 0, z: 1600,
        sizeX: 320, sizeY: 180, sizeZ: 40,
        material: 'brick',
      ),

      // ── stairway ───────────────────────────────────────────────────────────
      MapObjectData(
        id: 'stairs_main', shape: MapObjectShape.stairs,
        x: -200, y: 0, z: 900,
        sizeX: 160, sizeY: 300, sizeZ: 450,
        material: 'stone',
        props: {'steps': 5, 'stepWidth': 160, 'stepHeight': 60, 'stepDepth': 90},
      ),

      // ── floating platforms ─────────────────────────────────────────────────
      MapObjectData(
        id: 'plat_low',  shape: MapObjectShape.platform,
        x: 300, y: 200, z: 1000,
        sizeX: 280, sizeY: 30, sizeZ: 140,
        material: 'stone',
      ),
      MapObjectData(
        id: 'plat_high', shape: MapObjectShape.platform,
        x: -100, y: 380, z: 1400,
        sizeX: 240, sizeY: 30, sizeZ: 120,
        material: 'brick',
      ),
      MapObjectData(
        id: 'plat_far',  shape: MapObjectShape.platform,
        x: 200, y: 280, z: 2200,
        sizeX: 300, sizeY: 30, sizeZ: 150,
        material: 'stone',
      ),
    ],
  );

  // ──────────────────────────────────────────────────────────────────────────

  /// Compound structures: arches, pyramids, elevated platforms, cones.
  static MapData3D _ancientRuins() => MapData3D(
    id:   'ancient_ruins',
    name: 'Ancient Ruins',
    worldWidth: 2400,
    worldDepth: 4000,
    objects: [
      // ── archway entrance ───────────────────────────────────────────────────
      MapObjectData(
        id: 'arch_entrance', shape: MapObjectShape.arch,
        x: 0, y: 0, z: 500,
        sizeX: 440, sizeY: 280, sizeZ: 80,
        material: 'stone',
        props: {
          'openingWidth': 280, 'pillarWidth': 80,
          'pillarHeight': 280, 'pillarDepth': 80, 'lintelThick': 60,
        },
      ),

      // ── central pyramid ────────────────────────────────────────────────────
      MapObjectData(
        id: 'pyramid_main', shape: MapObjectShape.pyramid,
        x: 0, y: 0, z: 1400,
        sizeX: 480, sizeY: 240, sizeZ: 480,
        material: 'stone',
        props: {'layers': 4, 'baseWidth': 480, 'layerHeight': 60, 'stepInset': 60},
      ),

      // ── flanking pillars (boxes) ───────────────────────────────────────────
      MapObjectData(
        id: 'pillar_left',  shape: MapObjectShape.box,
        x: -500, y: 0, z: 1400,
        sizeX: 80, sizeY: 300, sizeZ: 80,
        material: 'stone',
      ),
      MapObjectData(
        id: 'pillar_right', shape: MapObjectShape.box,
        x:  500, y: 0, z: 1400,
        sizeX: 80, sizeY: 300, sizeZ: 80,
        material: 'stone',
      ),

      // ── elevated viewing platform ──────────────────────────────────────────
      MapObjectData(
        id: 'elevated_left', shape: MapObjectShape.elevatedPlatform,
        x: -380, y: 0, z: 2200,
        sizeX: 500, sizeY: 240, sizeZ: 200,
        material: 'stone',
        props: {
          'platformHeight': 240, 'platformWidth': 500, 'platformDepth': 200,
          'slabThickness': 60,   'columnWidth': 100,
        },
      ),
      MapObjectData(
        id: 'elevated_right', shape: MapObjectShape.elevatedPlatform,
        x:  380, y: 0, z: 2200,
        sizeX: 500, sizeY: 240, sizeZ: 200,
        material: 'brick',
        props: {
          'platformHeight': 240, 'platformWidth': 500, 'platformDepth': 200,
          'slabThickness': 60,   'columnWidth': 100,
        },
      ),

      // ── decorative cones (obelisk tops, box collision hull) ────────────────
      MapObjectData(
        id: 'cone_left',  shape: MapObjectShape.cone,
        x: -500, y: 300, z: 1400,
        sizeX: 60, sizeY: 120, sizeZ: 60,
        material: 'stone',
      ),
      MapObjectData(
        id: 'cone_right', shape: MapObjectShape.cone,
        x:  500, y: 300, z: 1400,
        sizeX: 60, sizeY: 120, sizeZ: 60,
        material: 'stone',
      ),

      // ── rear arch ─────────────────────────────────────────────────────────
      MapObjectData(
        id: 'arch_rear', shape: MapObjectShape.arch,
        x: 0, y: 0, z: 3200,
        sizeX: 440, sizeY: 320, sizeZ: 80,
        material: 'brick',
        props: {
          'openingWidth': 300, 'pillarWidth': 80,
          'pillarHeight': 320, 'pillarDepth': 80, 'lintelThick': 80,
        },
      ),
    ],
  );

  // ──────────────────────────────────────────────────────────────────────────

  /// Mixed traversal: ramps, zigzag, cylinders, triangular wedges.
  static MapData3D _industrialZone() => MapData3D(
    id:   'industrial_zone',
    name: 'Industrial Zone',
    worldWidth: 2400,
    worldDepth: 4000,
    objects: [
      // ── large ramp (left side) ─────────────────────────────────────────────
      MapObjectData(
        id: 'ramp_left', shape: MapObjectShape.ramp,
        x: -400, y: 0, z: 600,
        sizeX: 200, sizeY: 240, sizeZ: 480,
        material: 'metal',
        props: {'subdivisions': 8},
      ),

      // ── large ramp (right side, mirrored) ─────────────────────────────────
      MapObjectData(
        id: 'ramp_right', shape: MapObjectShape.ramp,
        x:  400, y: 0, z: 600,
        sizeX: 200, sizeY: 240, sizeZ: 480,
        material: 'metal',
        props: {'subdivisions': 8},
      ),

      // ── cylindrical tanks ─────────────────────────────────────────────────
      MapObjectData(
        id: 'tank_a', shape: MapObjectShape.cylinder,
        x: -200, y: 0, z: 1300,
        sizeX: 160, sizeY: 200, sizeZ: 160,
        material: 'metal',
      ),
      MapObjectData(
        id: 'tank_b', shape: MapObjectShape.cylinder,
        x:  200, y: 0, z: 1300,
        sizeX: 160, sizeY: 200, sizeZ: 160,
        material: 'metal',
      ),
      MapObjectData(
        id: 'tank_c', shape: MapObjectShape.cylinder,
        x: 0, y: 200, z: 1300,
        sizeX: 120, sizeY: 160, sizeZ: 120,
        material: 'metal',
      ),

      // ── triangular wedge obstacles ─────────────────────────────────────────
      MapObjectData(
        id: 'wedge_left',  shape: MapObjectShape.triangle,
        x: -500, y: 0, z: 1900,
        sizeX: 200, sizeY: 120, sizeZ: 200,
        material: 'dirt',
      ),
      MapObjectData(
        id: 'wedge_right', shape: MapObjectShape.triangle,
        x:  500, y: 0, z: 1900,
        sizeX: 200, sizeY: 120, sizeZ: 200,
        material: 'dirt',
      ),

      // ── zigzag path upward ─────────────────────────────────────────────────
      MapObjectData(
        id: 'zigzag_main', shape: MapObjectShape.zigzag,
        x: 0, y: 0, z: 2400,
        sizeX: 260, sizeY: 240, sizeZ: 560,
        material: 'metal',
        props: {'levels': 4, 'levelHeight': 60, 'blockWidth': 260, 'blockDepth': 140},
      ),

      // ── top platform after zigzag ──────────────────────────────────────────
      MapObjectData(
        id: 'plat_summit', shape: MapObjectShape.platform,
        x: 0, y: 240, z: 3200,
        sizeX: 400, sizeY: 30, sizeZ: 200,
        material: 'metal',
      ),

      // ── wall barriers ─────────────────────────────────────────────────────
      MapObjectData(
        id: 'wall_barrier_a', shape: MapObjectShape.wall,
        x: -300, y: 0, z: 3600,
        sizeX: 280, sizeY: 200, sizeZ: 40,
        material: 'metal',
      ),
      MapObjectData(
        id: 'wall_barrier_b', shape: MapObjectShape.wall,
        x:  300, y: 0, z: 3600,
        sizeX: 280, sizeY: 200, sizeZ: 40,
        material: 'metal',
      ),
    ],
  );

  // ──────────────────────────────────────────────────────────────────────────

  /// Open fight space: low cover boxes + wall lanes for tactical play.
  static MapData3D _combatArena() => MapData3D(
    id:   'combat_arena',
    name: 'Combat Arena',
    worldWidth: 3200,
    worldDepth: 3200,
    objects: [
      // ── centre raised platform ─────────────────────────────────────────────
      MapObjectData(
        id: 'centre_platform', shape: MapObjectShape.platform,
        x: 0, y: 120, z: 1600,
        sizeX: 360, sizeY: 30, sizeZ: 180,
        material: 'stone',
      ),

      // ── centre support (box below platform) ───────────────────────────────
      MapObjectData(
        id: 'centre_support', shape: MapObjectShape.box,
        x: 0, y: 0, z: 1600,
        sizeX: 200, sizeY: 120, sizeZ: 140,
        material: 'stone',
      ),

      // ── L-shaped cover (two boxes) ─────────────────────────────────────────
      MapObjectData(
        id: 'cover_nw_a', shape: MapObjectShape.box,
        x: -600, y: 0, z: 800,
        sizeX: 240, sizeY: 80, sizeZ: 80,
        material: 'brick',
      ),
      MapObjectData(
        id: 'cover_nw_b', shape: MapObjectShape.box,
        x: -520, y: 0, z: 880,
        sizeX: 80, sizeY: 80, sizeZ: 240,
        material: 'brick',
      ),

      MapObjectData(
        id: 'cover_ne_a', shape: MapObjectShape.box,
        x:  600, y: 0, z: 800,
        sizeX: 240, sizeY: 80, sizeZ: 80,
        material: 'brick',
      ),
      MapObjectData(
        id: 'cover_ne_b', shape: MapObjectShape.box,
        x:  520, y: 0, z: 880,
        sizeX: 80, sizeY: 80, sizeZ: 240,
        material: 'brick',
      ),

      // ── rear wall cover ────────────────────────────────────────────────────
      MapObjectData(
        id: 'wall_south_l', shape: MapObjectShape.wall,
        x: -400, y: 0, z: 2600,
        sizeX: 360, sizeY: 160, sizeZ: 40,
        material: 'stone',
      ),
      MapObjectData(
        id: 'wall_south_r', shape: MapObjectShape.wall,
        x:  400, y: 0, z: 2600,
        sizeX: 360, sizeY: 160, sizeZ: 40,
        material: 'stone',
      ),

      // ── corner stairs ─────────────────────────────────────────────────────
      MapObjectData(
        id: 'stairs_sw', shape: MapObjectShape.stairs,
        x: -700, y: 0, z: 2200,
        sizeX: 160, sizeY: 180, sizeZ: 270,
        material: 'stone',
        props: {'steps': 3, 'stepWidth': 160, 'stepHeight': 60, 'stepDepth': 90},
      ),
      MapObjectData(
        id: 'stairs_se', shape: MapObjectShape.stairs,
        x:  700, y: 0, z: 2200,
        sizeX: 160, sizeY: 180, sizeZ: 270,
        material: 'stone',
        props: {'steps': 3, 'stepWidth': 160, 'stepHeight': 60, 'stepDepth': 90},
      ),

      // ── sniper perch (elevated platform + arch below) ─────────────────────
      MapObjectData(
        id: 'arch_north', shape: MapObjectShape.arch,
        x: 0, y: 0, z: 400,
        sizeX: 440, sizeY: 240, sizeZ: 80,
        material: 'stone',
        props: {
          'openingWidth': 280, 'pillarWidth': 80,
          'pillarHeight': 240, 'pillarDepth': 80, 'lintelThick': 60,
        },
      ),
      MapObjectData(
        id: 'perch_north', shape: MapObjectShape.platform,
        x: 0, y: 300, z: 400,
        sizeX: 320, sizeY: 30, sizeZ: 160,
        material: 'stone',
      ),
    ],
  );
}
