// Example Usage Scenarios for Procedural Map Generator

import 'package:nomercy/map/map_generator_config.dart';
import 'package:nomercy/map/map_loader.dart';


class MapGeneratorExamples {

  // ============= BASIC EXAMPLES =============

  /// Example 1: Quickstart - Random Map
  void example1_quickStart() {
    // Simplest way - completely random map
    final map = MapLoader.generateRandomMap();

    print('Generated random map with ${map.platforms.length} platforms');
  }

  /// Example 2: Specific Style
  void example2_specificStyle() {
    // Generate a specific style
    final arenaMap = MapLoader.generateStyleMap(
      MapStyle.arena,
      difficulty: MapDifficulty.medium,
    );

    print('Generated ${arenaMap.name}');
  }

  /// Example 3: Custom Configuration
  void example3_customConfig() {
    final config = MapGeneratorConfig(
      style: MapStyle.platformer,
      difficulty: MapDifficulty.hard,
      width: 2400,
      height: 1200,
      minPlatforms: 12,
      maxPlatforms: 18,
      chestCount: 4,
      ensureConnectivity: true,
    );

    final map = MapLoader.generateProceduralMap(config);
    print('Custom map generated!');
  }

  // ============= GAME MODE EXAMPLES =============

  /// Example 4: Survival Mode - Progressive Difficulty
  void example4_survivalMode(int currentWave) {
    // Maps get harder as waves progress
    final map = MapLoader.generateWaveMap(currentWave);

    // Wave 1-3: Easy
    // Wave 4-7: Medium
    // Wave 8-12: Hard
    // Wave 13+: Expert

    print('Wave $currentWave map generated');
  }

  /// Example 5: Boss Fight Arena
  void example5_bossArena() {
    final bossMap = MapLoader.generateBossArena();

    // Generates a special arena:
    // - Medium difficulty
    // - Arena style (open combat)
    // - 5-8 platforms
    // - 2 chests

    print('Boss arena ready!');
  }

  /// Example 6: Campaign with Mixed Maps
  void example6_campaignMaps(int level) {
    final campaignMaps = {
      1: MapGeneratorConfig(
        style: MapStyle.balanced,
        difficulty: MapDifficulty.easy,
        seed: 1001, // Fixed seed for consistency
      ),
      2: MapGeneratorConfig(
        style: MapStyle.platformer,
        difficulty: MapDifficulty.medium,
        seed: 1002,
      ),
      3: MapGeneratorConfig(
        style: MapStyle.towers,
        difficulty: MapDifficulty.hard,
        seed: 1003,
      ),
    };

    final config = campaignMaps[level];
    if (config != null) {
      final map = MapLoader.generateProceduralMap(config);
      print('Campaign level $level loaded');
    }
  }

  // ============= ADVANCED EXAMPLES =============

  /// Example 7: Daily Challenge Map
  void example7_dailyChallenge() {
    // Everyone gets same map each day
    final now = DateTime.now();
    final dailySeed = now.year * 10000 + now.month * 100 + now.day;

    final map = MapLoader.generateProceduralMap(
      MapGeneratorConfig(
        style: MapStyle.chaos, // Different every day
        difficulty: MapDifficulty.hard,
        seed: dailySeed,
      ),
    );

    print('Daily challenge map: Seed $dailySeed');
  }

  /// Example 8: Speedrun Categories
  void example8_speedrunMap() {
    // Fixed seed for competitive play
    const speedrunSeed = 42069;

    final map = MapLoader.generateProceduralMap(
      MapGeneratorConfig(
        style: MapStyle.platformer,
        difficulty: MapDifficulty.expert,
        seed: speedrunSeed,
      ),
    );

    print('Speedrun map loaded - all players get same layout');
  }

  /// Example 9: Training Grounds
  void example9_trainingMap() {
    final trainingMap = MapLoader.generateProceduralMap(
      MapGeneratorConfig(
        style: MapStyle.balanced,
        difficulty: MapDifficulty.easy,
        minPlatforms: 6,
        maxPlatforms: 10,
        chestCount: 1,
        width: 1600, // Smaller map
        height: 900,
      ),
    );

    print('Training map generated - learn the basics!');
  }

  /// Example 10: PvP Symmetrical Arena
  void example10_pvpMap() {
    // Note: Current generator doesn't enforce symmetry
    // This would need custom implementation

    final pvpMap = MapLoader.generateProceduralMap(
      MapGeneratorConfig(
        style: MapStyle.arena,
        difficulty: MapDifficulty.medium,
        minPlatforms: 6,
        maxPlatforms: 10,
        chestCount: 2,
        seed: 999, // Fixed for fairness
      ),
    );

    print('PvP arena generated');
  }

  // ============= TESTING & DEBUGGING =============

  /// Test all map styles
  void test_allStyles() {
    print('Testing all map styles...\n');

    for (final style in MapStyle.values) {
      final map = MapLoader.generateProceduralMap(
        MapGeneratorConfig(
          style: style,
          difficulty: MapDifficulty.medium,
        ),
      );

      print('✓ ${style.name}: ${map.platforms.length} platforms, ${map.chests.length} chests');
    }
  }

  /// Test all difficulties
  void test_allDifficulties() {
    print('Testing all difficulties...\n');

    for (final difficulty in MapDifficulty.values) {
      final map = MapLoader.generateProceduralMap(
        MapGeneratorConfig(
          style: MapStyle.balanced,
          difficulty: difficulty,
        ),
      );

      // Check platform widths
      final avgWidth = map.platforms
          .map((p) => p.width)
          .reduce((a, b) => a + b) / map.platforms.length;

      print('✓ ${difficulty.name}: Avg platform width: ${avgWidth.toInt()}px');
    }
  }

  /// Test seed reproducibility
  void test_seedReproducibility() {
    print('Testing seed reproducibility...\n');

    const testSeed = 12345;

    final map1 = MapLoader.generateProceduralMap(
      MapGeneratorConfig(seed: testSeed),
    );

    final map2 = MapLoader.generateProceduralMap(
      MapGeneratorConfig(seed: testSeed),
    );

    // Check if maps are identical
    final identical = map1.platforms.length == map2.platforms.length &&
        map1.playerSpawn.x == map2.playerSpawn.x &&
        map1.playerSpawn.y == map2.playerSpawn.y;

    print(identical
        ? '✓ Same seed produces identical maps'
        : '✗ ERROR: Maps differ with same seed!');
  }

  /// Benchmark generation speed
  void test_generationSpeed() {
    print('Benchmarking generation speed...\n');

    final configs = [
      ('Easy Balanced', MapGeneratorConfig(
        style: MapStyle.balanced,
        difficulty: MapDifficulty.easy,
        maxPlatforms: 10,
      )),
      ('Hard Platformer', MapGeneratorConfig(
        style: MapStyle.platformer,
        difficulty: MapDifficulty.hard,
        maxPlatforms: 15,
      )),
      ('Expert Chaos', MapGeneratorConfig(
        style: MapStyle.chaos,
        difficulty: MapDifficulty.expert,
        maxPlatforms: 20,
      )),
    ];

    for (final (name, config) in configs) {
      final stopwatch = Stopwatch()..start();
      MapLoader.generateProceduralMap(config);
      stopwatch.stop();

      print('✓ $name: ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  /// Test connectivity validation
  void test_connectivity() {
    print('Testing connectivity...\n');

    final map = MapLoader.generateProceduralMap(
      MapGeneratorConfig(
        style: MapStyle.chaos,
        difficulty: MapDifficulty.hard,
        maxPlatforms: 15,
        ensureConnectivity: true,
      ),
    );

    print('✓ Map generated with connectivity validation');
    print('  Platforms: ${map.platforms.length}');
    print('  All areas should be reachable from spawn');
  }

  // ============= EXPORT & SAVE =============

  /// Export map to JSON for manual editing
  void export_mapToJson() {
    final map = MapLoader.generateProceduralMap(
      MapGeneratorConfig(
        style: MapStyle.arena,
        difficulty: MapDifficulty.medium,
        seed: 55555,
      ),
    );

    final jsonString = MapLoader.exportMapToJson(map);

    print('Map exported to JSON:');
    print(jsonString);

    // Save to file:
    // File('assets/maps/custom_arena.json').writeAsStringSync(jsonString);
  }

  // ============= INTEGRATION WITH GAME MANAGER =============

  /// Example: Generate new map each wave
  void integration_waveSystem(int waveNumber) {
    // Clear old cache to free memory
    if (waveNumber % 5 == 0) {
      MapLoader.clearCache();
    }

    // Generate map based on wave
    final map = MapLoader.generateWaveMap(waveNumber);

    // Use this map in your game
    print('Wave $waveNumber: New map with ${map.platforms.length} platforms');
  }

  /// Example: Boss fight with special arena
  void integration_bossWave() {
    final bossArena = MapLoader.generateBossArena();

    print('BOSS WAVE!');
    print('Special arena loaded: ${bossArena.platforms.length} platforms');
    // Spawn boss at center of map
  }
}

// ============= USAGE IN YOUR GAME =============

/*

// In your game initialization:

@override
Future<void> onLoad() async {
  // ... existing code ...

  // Load procedural map
  final gameMap = procedural
      ? MapLoader.generateWaveMap(currentWave)
      : await MapLoader.loadMapFromJson(mapName);

  // Create platforms from map
  for (final platformData in gameMap.platforms) {
    final platform = TiledPlatform(
      position: Vector2(platformData.x, platformData.y),
      size: Vector2(platformData.width, platformData.height),
      platformType: platformData.type,
    );
    world.add(platform);
    platforms.add(platform);
  }

  // ... rest of setup ...
}

*/

// ============= QUICK REFERENCE =============

class QuickReference {
  void cheatSheet() {
    // Generate random map
    final map1 = MapLoader.generateRandomMap();

    // Generate specific style
    final map2 = MapLoader.generateStyleMap(MapStyle.arena);

    // Generate for wave
    final map3 = MapLoader.generateWaveMap(5);

    // Generate boss arena
    final map4 = MapLoader.generateBossArena();

    // Custom config
    final map5 = MapLoader.generateProceduralMap(
      MapGeneratorConfig(
        style: MapStyle.platformer,
        difficulty: MapDifficulty.hard,
        seed: 12345,
      ),
    );

    // Export to JSON
    final json = MapLoader.exportMapToJson(map1);

    // Clear cache
    MapLoader.clearCache();
  }
}