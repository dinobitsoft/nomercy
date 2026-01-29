import 'dart:convert';
import 'package:engine/engine.dart';
import 'package:flutter/services.dart';
import 'package:ui/ui.dart';

import 'entity/game_map.dart';

class MapLoader {
  // Cache for generated maps (so same seed produces same map)
  static final Map<int, GameMap> _generatedMapCache = {};

  /// Load a map - either from JSON file or generate procedurally
  static Future<GameMap> loadMap(String mapName, {
    bool procedural = false,
    MapGeneratorConfig? config,
  }) async {
    if (procedural) {
      return generateProceduralMap(config ?? MapGeneratorConfig(startX: 0.0,));
    }

    // Check if mapName is a special procedural identifier
    if (mapName.startsWith('procedural_')) {
      // Extract seed from name
      final seed = int.tryParse(mapName.replaceFirst('procedural_', ''));
      if (seed != null) {
        return generateProceduralMap(MapGeneratorConfig(seed: seed, startX: 0.0,));
      }
    }

    // Load from JSON
    return await loadMapFromJson(mapName);
  }

  /// Load map from JSON file
  static Future<GameMap> loadMapFromJson(String mapName) async {
    try {
      print('Loading map from JSON: $mapName');
      final jsonString = await rootBundle.loadString('assets/maps/$mapName.json');
      final jsonData = json.decode(jsonString);
      return GameMap.fromJson(jsonData);
    } catch (e) {
      print('Error loading map: $e');
      print('Generating default map instead...');
      return _getDefaultMap();
    }
  }

  /// Generate a procedural map
  static GameMap generateProceduralMap(MapGeneratorConfig config) {
    // Check cache first
    if (_generatedMapCache.containsKey(config.seed)) {
      print('Using cached map for seed ${config.seed}');
      return _generatedMapCache[config.seed]!;
    }

    // Generate new map
    final generator = ProceduralMapGenerator(seed: config.seed);
    final map = generator.generate();

    // Cache it
    _generatedMapCache[config.seed] = map;

    return map;
  }

  /// Generate a random map based on difficulty
  static GameMap generateRandomMap({MapDifficulty difficulty = MapDifficulty.medium}) {
    final styles = MapStyle.values;
    final randomStyle = styles[DateTime.now().millisecondsSinceEpoch % styles.length];

    return generateProceduralMap(MapGeneratorConfig(
      style: randomStyle,
      difficulty: difficulty, startX: 0.0,
    ));
  }

  /// Generate specific style map
  static GameMap generateStyleMap(MapStyle style, {MapDifficulty difficulty = MapDifficulty.medium}) {
    return generateProceduralMap(MapGeneratorConfig(
      style: style,
      difficulty: difficulty, startX: 0.0, //TODO: implement
    ));
  }

  /// Generate map for specific wave (scales with wave number)
  static GameMap generateWaveMap(int waveNumber) {
    // Increase difficulty with wave number
    MapDifficulty difficulty;
    if (waveNumber <= 3) {
      difficulty = MapDifficulty.easy;
    } else if (waveNumber <= 7) {
      difficulty = MapDifficulty.medium;
    } else if (waveNumber <= 12) {
      difficulty = MapDifficulty.hard;
    } else {
      difficulty = MapDifficulty.expert;
    }

    // Rotate through styles
    final styles = [
      MapStyle.balanced,
      MapStyle.arena,
      MapStyle.platformer,
      MapStyle.towers,
    ];
    final style = styles[waveNumber % styles.length];

    return generateProceduralMap(MapGeneratorConfig(
      style: style,
      difficulty: difficulty,
      seed: waveNumber * 1000, // Reproducible maps per wave
      startX: 0.0,
    ));
  }

  /// Generate a boss arena
  static GameMap generateBossArena() {
    return generateProceduralMap(MapGeneratorConfig(
      style: MapStyle.arena,
      difficulty: MapDifficulty.medium,
      minPlatforms: 5,
      maxPlatforms: 8,
      chestCount: 2,
      width: 2000,
      height: 1000,
      startX: 0.0,
    ));
  }

  /// Save generated map to JSON (for manual editing later)
  static String exportMapToJson(GameMap map) {
    final jsonData = map.toJson();
    return const JsonEncoder.withIndent('  ').convert(jsonData);
  }

  static GameMap _getDefaultMap() {
    return GameMap(
      name: 'default',
      width: 1920,
      height: 1080,
      platforms: [
        PlatformData(
          type: 'ground',
          x: 960,
          y: 1000,
          width: 1920,
          height: 80,
        ),
        PlatformData(
          type: 'brick',
          x: 500,
          y: 700,
          width: 200,
          height: 40,
        ),
        PlatformData(
          type: 'brick',
          x: 1400,
          y: 700,
          width: 200,
          height: 40,
        ),
      ],
      playerSpawn: SpawnPoint(x: 200, y: 800),
      chests: [],
    );
  }

  /// Clear the cache (useful for freeing memory)
  static void clearCache() {
    _generatedMapCache.clear();
    print('Map cache cleared');
  }
}