// modules/engine/lib/src/map/map_data_3d.dart

import 'map_object_data.dart';

/// Full description of a 3D map — world bounds plus every object it contains.
///
/// Instances are produced by a [MapDataController] (network or mock) and
/// converted to live game components by [MapMaker3D].
class MapData3D {
  final String id;
  final String name;

  /// Total playable width in world units (X axis).
  final double worldWidth;

  /// Total playable depth in world units (Z axis).
  final double worldDepth;

  /// All map objects: obstacles, platforms, structures, etc.
  final List<MapObjectData> objects;

  const MapData3D({
    required this.id,
    required this.name,
    this.worldWidth = 2400.0,
    this.worldDepth = 3200.0,
    required this.objects,
  });

  factory MapData3D.fromJson(Map<String, dynamic> json) => MapData3D(
        id:         json['id']         as String,
        name:       json['name']       as String,
        worldWidth: (json['worldWidth'] as num?)?.toDouble() ?? 2400.0,
        worldDepth: (json['worldDepth'] as num?)?.toDouble() ?? 3200.0,
        objects: (json['objects'] as List<dynamic>)
            .map((e) => MapObjectData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id':         id,
        'name':       name,
        'worldWidth': worldWidth,
        'worldDepth': worldDepth,
        'objects':    objects.map((o) => o.toJson()).toList(),
      };

  @override
  String toString() =>
      'MapData3D(id: $id, name: "$name", '
      '${objects.length} objects, '
      '${worldWidth.toInt()}×${worldDepth.toInt()} world)';
}
