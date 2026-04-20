// modules/engine/lib/src/map/map_maker_3d.dart

import 'package:core/core.dart';

import '../components/obstacle/obstacle_3d.dart';
import '../components/obstacle/obstacle_builder_3d.dart';
import '../components/platform/game_platform_3d.dart';
import 'map_data_3d.dart';
import 'map_object_data.dart';

/// Output of [MapMaker3D.build]: separate lists ready to be added to
/// [ActionGame3D.obstacles3D] and [ActionGame3D.platforms3D].
class MapResult3D {
  final List<Obstacle3D>     obstacles;
  final List<GamePlatform3D> platforms;

  const MapResult3D({
    required this.obstacles,
    required this.platforms,
  });

  /// Total component count for logging / diagnostics.
  int get componentCount => obstacles.length + platforms.length;
}

// ─────────────────────────────────────────────────────────────────────────────

/// Converts a [MapData3D] (plain data) into live Flame components.
///
/// ## Y convention
/// [MapObjectData.y] is always the **floor / bottom-Y** of the structure.
/// For single-box shapes this means `worldPos.y = obj.y + obj.sizeY` (top face).
/// For compound builder shapes [obj.y] is passed as `groundY`.
///
/// ## Usage
/// ```dart
/// final result = MapMaker3D.build(mapData);
///
/// for (final obs in result.obstacles) {
///   game.add(obs);
///   game.obstacles3D.add(obs);
/// }
/// for (final plt in result.platforms) {
///   game.add(plt);
///   game.platforms3D.add(plt);
/// }
/// ```
abstract final class MapMaker3D {

  static MapResult3D build(MapData3D data) {
    final obstacles = <Obstacle3D>[];
    final platforms = <GamePlatform3D>[];

    for (final obj in data.objects) {
      switch (obj.shape) {

        // ── single-box obstacles ─────────────────────────────────────────────

        case MapObjectShape.box:
        case MapObjectShape.wall:
        case MapObjectShape.triangle:
        case MapObjectShape.cone:
        case MapObjectShape.cylinder:
          // y is floor; Obstacle3D.worldPos.y is top face.
          obstacles.add(Obstacle3D(
            worldPos:     WorldPos(obj.x, obj.y + obj.sizeY, obj.z),
            sizeX:        obj.sizeX,
            sizeY:        obj.sizeY,
            sizeZ:        obj.sizeZ,
            obstacleType: obj.material,
          ));

        // ── floating platform ────────────────────────────────────────────────

        case MapObjectShape.platform:
          platforms.add(GamePlatform3D(
            worldPos:     WorldPos(obj.x, obj.y + obj.sizeY, obj.z),
            sizeX:        obj.sizeX,
            sizeY:        obj.sizeY,
            sizeZ:        obj.sizeZ,
            platformType: obj.material,
          ));

        // ── stairway ─────────────────────────────────────────────────────────

        case MapObjectShape.stairs:
          obstacles.addAll(ObstacleBuilder3D.stairway(
            origin:     WorldPos(obj.x, obj.y, obj.z),
            steps:      _intProp(obj, 'steps',      5),
            stepWidth:  _dblProp(obj, 'stepWidth',  obj.sizeX),
            stepHeight: _dblProp(obj, 'stepHeight', 60.0),
            stepDepth:  _dblProp(obj, 'stepDepth',  90.0),
            type:       obj.material,
          ));

        // ── ramp (dense stairway approximation) ──────────────────────────────

        case MapObjectShape.ramp:
          final steps = _intProp(obj, 'subdivisions', 6);
          obstacles.addAll(ObstacleBuilder3D.stairway(
            origin:     WorldPos(obj.x, obj.y, obj.z),
            steps:      steps,
            stepWidth:  obj.sizeX,
            stepHeight: obj.sizeY / steps,
            stepDepth:  obj.sizeZ / steps,
            type:       obj.material,
          ));

        // ── elevated platform ────────────────────────────────────────────────

        case MapObjectShape.elevatedPlatform:
          obstacles.addAll(ObstacleBuilder3D.elevatedPlatform(
            origin:         WorldPos(obj.x, obj.y, obj.z),
            platformHeight: _dblProp(obj, 'platformHeight', obj.sizeY),
            platformWidth:  _dblProp(obj, 'platformWidth',  obj.sizeX),
            platformDepth:  _dblProp(obj, 'platformDepth',  obj.sizeZ),
            slabThickness:  _dblProp(obj, 'slabThickness',  60.0),
            columnWidth:    _dblProp(obj, 'columnWidth',     100.0),
            groundY:        obj.y,
            type:           obj.material,
          ));

        // ── archway ──────────────────────────────────────────────────────────

        case MapObjectShape.arch:
          obstacles.addAll(ObstacleBuilder3D.archway(
            origin:       WorldPos(obj.x, obj.y, obj.z),
            openingWidth: _dblProp(obj, 'openingWidth', 280.0),
            pillarWidth:  _dblProp(obj, 'pillarWidth',  80.0),
            pillarHeight: _dblProp(obj, 'pillarHeight', obj.sizeY),
            pillarDepth:  _dblProp(obj, 'pillarDepth',  80.0),
            lintelThick:  _dblProp(obj, 'lintelThick',  60.0),
            groundY:      obj.y,
            type:         obj.material,
          ));

        // ── zigzag ramp ──────────────────────────────────────────────────────

        case MapObjectShape.zigzag:
          obstacles.addAll(ObstacleBuilder3D.zigzagRamp(
            origin:      WorldPos(obj.x, obj.y, obj.z),
            levels:      _intProp(obj, 'levels',      4),
            levelHeight: _dblProp(obj, 'levelHeight', 60.0),
            blockWidth:  _dblProp(obj, 'blockWidth',  obj.sizeX),
            blockDepth:  _dblProp(obj, 'blockDepth',  obj.sizeZ),
            groundY:     obj.y,
            type:        obj.material,
          ));

        // ── pyramid ──────────────────────────────────────────────────────────

        case MapObjectShape.pyramid:
          obstacles.addAll(ObstacleBuilder3D.pyramid(
            origin:      WorldPos(obj.x, obj.y, obj.z),
            layers:      _intProp(obj, 'layers',      4),
            baseWidth:   _dblProp(obj, 'baseWidth',   obj.sizeX),
            layerHeight: _dblProp(obj, 'layerHeight', 60.0),
            stepInset:   _dblProp(obj, 'stepInset',   60.0),
            groundY:     obj.y,
            type:        obj.material,
          ));

        // ── spawn markers — no game component created ─────────────────────────

        case MapObjectShape.spawnPlayer:
        case MapObjectShape.spawnBot:
          break;
      }
    }

    return MapResult3D(obstacles: obstacles, platforms: platforms);
  }

  // ── prop helpers ───────────────────────────────────────────────────────────

  static double _dblProp(MapObjectData obj, String key, double fallback) =>
      (obj.props[key] as num?)?.toDouble() ?? fallback;

  static int _intProp(MapObjectData obj, String key, int fallback) =>
      (obj.props[key] as num?)?.toInt() ?? fallback;
}
