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

