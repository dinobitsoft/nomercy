import 'package:core/core.dart';
import 'package:engine/engine.dart';

class GameMap {
  final String name;
  final double width;
  final double height;
  final List<PlatformData> platforms;
  final SpawnPoint playerSpawn;
  final List<SpawnPoint> multiplayerSpawns; // NEW: Multiple spawn points
  final List<ChestData> chests;
  final List<ItemData> items;

  GameMap({
    required this.name,
    required this.width,
    required this.height,
    required this.platforms,
    required this.playerSpawn,
    this.multiplayerSpawns = const [], // NEW
    required this.chests,
    this.items = const [],
  });

  factory GameMap.fromJson(Map<String, dynamic> json) {
    return GameMap(
      name: json['name'] ?? 'unnamed',
      width: (json['width'] ?? 1200).toDouble(),
      height: (json['height'] ?? 800).toDouble(),
      platforms: (json['platforms'] as List)
          .map((p) => PlatformData.fromJson(p))
          .toList(),
      playerSpawn: SpawnPoint.fromJson(json['playerSpawn']),
      multiplayerSpawns: (json['multiplayerSpawns'] as List? ?? []) // NEW
          .map((s) => SpawnPoint.fromJson(s))
          .toList(),
      chests: (json['chests'] as List? ?? [])
          .map((c) => ChestData.fromJson(c))
          .toList(),
      items: (json['items'] as List? ?? [])
          .map((i) => ItemData.fromJson(i))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'width': width,
      'height': height,
      'platforms': platforms.map((p) => p.toJson()).toList(),
      'playerSpawn': playerSpawn.toJson(),
      'multiplayerSpawns': multiplayerSpawns.map((s) => s.toJson()).toList(), // NEW
      'chests': chests.map((c) => c.toJson()).toList(),
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

}

class PlatformData {
  final int id;
  final String type; // 'brick', 'ground'
  final double x;
  final double y;
  final double width;
  final double height;

  PlatformData({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory PlatformData.fromJson(Map<String, dynamic> json) {
    return PlatformData(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'brick',
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      width: (json['width'] ?? 120).toDouble(),
      height: (json['height'] ?? 20).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }
}

class SpawnPoint {
  final double x;
  final double y;

  SpawnPoint({required this.x, required this.y});

  factory SpawnPoint.fromJson(Map<String, dynamic> json) {
    return SpawnPoint(
      x: (json['x'] ?? 100).toDouble(),
      y: (json['y'] ?? 600).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }
}

// Map Loader class
