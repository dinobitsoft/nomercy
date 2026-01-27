import 'dart:math' as math;
import 'dart:ui';
import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:ui/ui.dart';

enum MapStyle {
  arena,
  platformer,
  dungeon,
  towers,
  chaos,
  balanced,
}

enum MapDifficulty {
  easy,
  medium,
  hard,
  expert,
}

class MapGeneratorConfig {
  final MapStyle style;
  final MapDifficulty difficulty;
  final double width;
  final double height;
  final int minPlatforms;
  final int maxPlatforms;
  final int chestCount;
  final bool ensureConnectivity;
  final int seed;

  MapGeneratorConfig({
    this.style = MapStyle.balanced,
    this.difficulty = MapDifficulty.medium,
    this.width = 2400,
    this.height = 1200,
    this.minPlatforms = 8,
    this.maxPlatforms = 15,
    this.chestCount = 3,
    this.ensureConnectivity = true,
    int? seed,
  }) : seed = seed ?? DateTime.now().millisecondsSinceEpoch;
}

class GeneratedPlatform {
  final Vector2 position;
  final Vector2 size;
  final String type;
  final int layer;

  GeneratedPlatform({
    required this.position,
    required this.size,
    required this.type,
    this.layer = 0,
  });

  bool overlaps(GeneratedPlatform other, {double margin = 20}) {
    return (position.x - size.x / 2 - margin < other.position.x + other.size.x / 2 + margin) &&
        (position.x + size.x / 2 + margin > other.position.x - other.size.x / 2 - margin) &&
        (position.y - size.y / 2 - margin < other.position.y + other.size.y / 2 + margin) &&
        (position.y + size.y / 2 + margin > other.position.y - other.size.y / 2 - margin);
  }

  bool isReachableFrom(GeneratedPlatform other) {
    final verticalDist = (position.y - other.position.y).abs();
    final horizontalDist = (position.x - other.position.x).abs();

    if (position.y < other.position.y) {
      return verticalDist <= GameConfig.maxJumpHeight &&
          horizontalDist <= GameConfig.maxJumpDistance;
    } else {
      return horizontalDist <= GameConfig.maxJumpDistance * 1.5;
    }
  }
}

class ProceduralMapGenerator {
  final MapGeneratorConfig config;
  late math.Random random;
  final List<GeneratedPlatform> platforms = [];
  final List<Vector2> chestPositions = [];
  Vector2? playerSpawn;
  final List<ItemData> itemDataList = [];

  ProceduralMapGenerator(this.config) {
    random = math.Random(config.seed);
  }

  GameMap generate() {
    print('╔════════════════════════════════════╗');
    print('║  Generating Procedural Map...     ║');
    print('╚════════════════════════════════════╝');
    print('Style: ${config.style}');
    print('Difficulty: ${config.difficulty}');
    print('Seed: ${config.seed}');

    platforms.clear();
    chestPositions.clear();

    // Generate based on style
    switch (config.style) {
      case MapStyle.arena:
        _generateArena();
        break;
      case MapStyle.platformer:
        _generatePlatformer();
        break;
      case MapStyle.dungeon:
        _generateDungeon();
        break;
      case MapStyle.towers:
        _generateTowers();
        break;
      case MapStyle.chaos:
        _generateChaos();
        break;
      case MapStyle.balanced:
        _generateBalanced();
        break;
    }

    // Ensure connectivity
    if (config.ensureConnectivity) {
      _ensureConnectivity();
    }

    // CRITICAL: Validate platforms before building
    _validatePlatforms();

    // Place spawns, chests, items
    _placePlayerSpawn();
    _placeChests();
    _placeItems();

    return _buildGameMap();
  }

  // ================================================================
  // GENERATION STRATEGIES - FIXED WITH BEST PRACTICES
  // ================================================================

  void _generateArena() {
    print('Generating Arena layout...');

    // ✅ FIXED: Full-width ground platform with proper thickness
    platforms.add(GeneratedPlatform(
      position: Vector2(config.width / 2, config.height - GameConfig.groundPlatformThickness / 2),
      size: Vector2(config.width * 0.95, GameConfig.groundPlatformThickness),
      type: 'ground',
      layer: 0,
    ));

    // Few elevated platforms
    final platformCount = 3 + random.nextInt(2);
    for (int i = 0; i < platformCount; i++) {
      final x = config.width * (0.2 + i * 0.25);
      final y = config.height - GameConfig.recommendedVerticalSpacing;

      platforms.add(GeneratedPlatform(
        position: Vector2(x, y),
        size: Vector2(
          GameConfig.minimumLandingZoneWidth + random.nextDouble() * 50,
          GameConfig.minimumPlatformThickness,
        ),
        type: 'brick',
        layer: 1,
      ));
    }
  }

  void _generatePlatformer() {
    print('Generating Platformer layout...');

    // ✅ Ground platform with proper thickness
    platforms.add(GeneratedPlatform(
      position: Vector2(config.width / 2, config.height - GameConfig.groundPlatformThickness / 2),
      size: Vector2(config.width, GameConfig.groundPlatformThickness),
      type: 'ground',
      layer: 0,
    ));

    // Create ascending platforms with safe spacing
    final layers = 4;
    final platformsPerLayer = 3;

    for (int layer = 1; layer <= layers; layer++) {
      final y = config.height - GameConfig.groundPlatformThickness -
          (layer * GameConfig.recommendedVerticalSpacing);

      _addPlatformLayerSafe(
        y: y,
        count: platformsPerLayer,
        layer: layer,
        width: GameConfig.minimumLandingZoneWidth,
        minSpacing: GameConfig.maxJumpDistance * 0.8,
      );
    }
  }

  void _generateDungeon() {
    print('Generating Dungeon layout...');

    // Ground platform
    platforms.add(GeneratedPlatform(
      position: Vector2(config.width / 2, config.height - GameConfig.groundPlatformThickness / 2),
      size: Vector2(config.width, GameConfig.groundPlatformThickness),
      type: 'ground',
      layer: 0,
    ));

    // Create rooms
    final rooms = <Rect>[];
    final roomCount = 3 + random.nextInt(2);

    for (int i = 0; i < roomCount; i++) {
      final roomWidth = 350.0 + random.nextDouble() * 150;
      final roomHeight = 250.0 + random.nextDouble() * 100;
      final x = 200 + random.nextDouble() * (config.width - roomWidth - 400);
      final y = 200 + random.nextDouble() * (config.height - roomHeight - 400);

      final room = Rect.fromLTWH(x, y, roomWidth, roomHeight);

      if (!rooms.any((r) => _rectsOverlap(r, room))) {
        rooms.add(room);
        _createRoom(room, i);
      }
    }

    // Connect rooms
    for (int i = 0; i < rooms.length - 1; i++) {
      _connectRooms(rooms[i], rooms[i + 1]);
    }
  }

  void _generateTowers() {
    print('Generating Towers layout...');

    // Ground platform
    platforms.add(GeneratedPlatform(
      position: Vector2(config.width / 2, config.height - GameConfig.groundPlatformThickness / 2),
      size: Vector2(config.width, GameConfig.groundPlatformThickness),
      type: 'ground',
      layer: 0,
    ));

    // Create vertical towers with safe spacing
    final towerCount = 3;
    final towerSpacing = config.width / (towerCount + 1);

    for (int t = 0; t < towerCount; t++) {
      final towerX = towerSpacing * (t + 1);
      final towerHeight = 3 + random.nextInt(2);

      for (int h = 0; h < towerHeight; h++) {
        final y = config.height - GameConfig.groundPlatformThickness -
            ((h + 1) * GameConfig.recommendedVerticalSpacing);

        platforms.add(GeneratedPlatform(
          position: Vector2(towerX, y),
          size: Vector2(
            GameConfig.minimumLandingZoneWidth,
            GameConfig.minimumPlatformThickness,
          ),
          type: 'brick',
          layer: h + 1,
        ));
      }
    }
  }

  void _generateChaos() {
    print('Generating Chaos layout...');

    // Ground platform
    platforms.add(GeneratedPlatform(
      position: Vector2(config.width / 2, config.height - GameConfig.groundPlatformThickness / 2),
      size: Vector2(config.width * 0.9, GameConfig.groundPlatformThickness),
      type: 'ground',
      layer: 0,
    ));

    // Random platforms with minimum safety
    final platformCount = config.minPlatforms +
        random.nextInt(config.maxPlatforms - config.minPlatforms);

    int attempts = 0;
    while (platforms.length < platformCount && attempts < platformCount * 5) {
      final x = 300 + random.nextDouble() * (config.width - 600);
      final y = 300 + random.nextDouble() * (config.height - 500);
      final width = _getPlatformWidth();

      final newPlatform = GeneratedPlatform(
        position: Vector2(x, y),
        size: Vector2(width, GameConfig.minimumPlatformThickness),
        type: random.nextBool() ? 'brick' : 'ground',
        layer: ((config.height - y) / GameConfig.recommendedVerticalSpacing).floor(),
      );

      if (!platforms.any((p) => p.overlaps(newPlatform, margin: GameConfig.platformSafetyMargin))) {
        platforms.add(newPlatform);
      }

      attempts++;
    }
  }

  void _generateBalanced() {
    print('Generating Balanced layout with Best Practices...');

    // ✅ GROUND PLATFORM: Full-width, 80px thick
    platforms.add(GeneratedPlatform(
      position: Vector2(
        config.width / 2,
        config.height - GameConfig.groundPlatformThickness / 2,
      ),
      size: Vector2(config.width * 0.90, GameConfig.groundPlatformThickness),
      type: 'ground',
      layer: 0,
    ));

    // ✅ LAYER 1: Low platforms (250px above ground)
    _addPlatformLayerSafe(
      y: config.height - GameConfig.groundPlatformThickness - GameConfig.recommendedVerticalSpacing,
      count: 4,
      layer: 1,
      width: GameConfig.minimumLandingZoneWidth,
      minSpacing: GameConfig.maxJumpDistance * 0.75,
    );

    // ✅ LAYER 2: Mid platforms (250px above layer 1)
    _addPlatformLayerSafe(
      y: config.height - GameConfig.groundPlatformThickness - (GameConfig.recommendedVerticalSpacing * 2),
      count: 3,
      layer: 2,
      width: GameConfig.minimumLandingZoneWidth,
      minSpacing: GameConfig.maxJumpDistance * 0.8,
    );

    // ✅ LAYER 3: High platforms (250px above layer 2)
    _addPlatformLayerSafe(
      y: config.height - GameConfig.groundPlatformThickness - (GameConfig.recommendedVerticalSpacing * 3),
      count: 2,
      layer: 3,
      width: GameConfig.minimumLandingZoneWidth * 0.9,
      minSpacing: GameConfig.maxJumpDistance * 0.85,
    );

    // Add some variety platforms (within safety constraints)
    for (int i = 0; i < 2; i++) {
      final x = 400 + random.nextDouble() * (config.width - 800);
      final y = 400 + random.nextDouble() * (config.height - 700);

      final newPlatform = GeneratedPlatform(
        position: Vector2(x, y),
        size: Vector2(
          _getPlatformWidth(),
          GameConfig.minimumPlatformThickness,
        ),
        type: 'brick',
        layer: ((config.height - y) / GameConfig.recommendedVerticalSpacing).floor(),
      );

      if (!platforms.any((p) => p.overlaps(newPlatform, margin: GameConfig.platformSafetyMargin))) {
        platforms.add(newPlatform);
      }
    }
  }

  // ================================================================
  // HELPER METHODS - FIXED WITH SAFETY CHECKS
  // ================================================================

  void _addPlatformLayerSafe({
    required double y,
    required int count,
    required int layer,
    required double width,
    required double minSpacing,
  }) {
    final totalSpacing = config.width / (count + 1);

    // ✅ VALIDATION: Check if spacing exceeds jump distance
    if (totalSpacing > GameConfig.maxJumpDistance) {
      DebugConfig.logPlatformWarning(
          'Platform spacing ($totalSpacing) exceeds max jump distance (${GameConfig.maxJumpDistance})'
      );
    }

    for (int i = 0; i < count; i++) {
      final baseX = totalSpacing * (i + 1);

      // Reduce randomness to maintain safe spacing
      final maxOffset = math.min(50.0, (totalSpacing - width) / 2 - GameConfig.platformSafetyMargin);
      final offset = (random.nextDouble() - 0.5) * maxOffset;

      final newPlatform = GeneratedPlatform(
        position: Vector2(baseX + offset, y),
        size: Vector2(
          width + random.nextDouble() * 30,
          GameConfig.minimumPlatformThickness,
        ),
        type: i % 2 == 0 ? 'brick' : 'ground',
        layer: layer,
      );

      // Ensure not overlapping
      bool tooClose = false;
      for (final existing in platforms) {
        if (existing.overlaps(newPlatform, margin: GameConfig.platformSafetyMargin)) {
          tooClose = true;
          break;
        }
      }

      if (!tooClose) {
        platforms.add(newPlatform);
      } else {
        DebugConfig.logPlatformWarning('Skipped overlapping platform at layer $layer');
      }
    }
  }

  void _createRoom(Rect room, int index) {
    platforms.add(GeneratedPlatform(
      position: Vector2(room.center.dx, room.bottom - GameConfig.minimumPlatformThickness / 2),
      size: Vector2(room.width, GameConfig.minimumPlatformThickness),
      type: 'ground',
      layer: 0,
    ));

    if (random.nextDouble() > 0.5) {
      platforms.add(GeneratedPlatform(
        position: Vector2(room.center.dx, room.center.dy),
        size: Vector2(
          GameConfig.minimumLandingZoneWidth,
          GameConfig.minimumPlatformThickness,
        ),
        type: 'brick',
        layer: 1,
      ));
    }
  }

  void _connectRooms(Rect room1, Rect room2) {
    final x1 = room1.center.dx;
    final y1 = room1.bottom - GameConfig.minimumPlatformThickness / 2;
    final x2 = room2.center.dx;
    final y2 = room2.bottom - GameConfig.minimumPlatformThickness / 2;

    final steps = ((x2 - x1).abs() / GameConfig.minimumLandingZoneWidth).ceil();

    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      final x = x1 + (x2 - x1) * t;
      final y = y1 + (y2 - y1) * t;

      platforms.add(GeneratedPlatform(
        position: Vector2(x, y),
        size: Vector2(
          GameConfig.minimumLandingZoneWidth,
          GameConfig.minimumPlatformThickness,
        ),
        type: 'brick',
        layer: 1,
      ));
    }
  }

  bool _rectsOverlap(Rect a, Rect b) => a.overlaps(b);

  double _getPlatformWidth() {
    // Always ensure minimum landing zone width
    final baseWidth = GameConfig.minimumLandingZoneWidth;

    switch (config.difficulty) {
      case MapDifficulty.easy:
        return baseWidth + random.nextDouble() * 100;
      case MapDifficulty.medium:
        return baseWidth + random.nextDouble() * 50;
      case MapDifficulty.hard:
        return baseWidth + random.nextDouble() * 30;
      case MapDifficulty.expert:
        return baseWidth; // Minimum only
    }
  }

  // ================================================================
  // VALIDATION - CRITICAL SAFETY CHECKS
  // ================================================================

  void _validatePlatforms() {
    print('╔════════════════════════════════════╗');
    print('║  Validating Platform Data...      ║');
    print('╚════════════════════════════════════╝');

    int warnings = 0;
    int errors = 0;

    for (int i = 0; i < platforms.length; i++) {
      final p = platforms[i];

      // Check for NaN
      if (p.position.x.isNaN || p.position.y.isNaN) {
        errors++;
        print('❌ ERROR: Platform $i has NaN position!');
        continue;
      }

      // Check for zero/negative size
      if (p.size.x <= 0 || p.size.y <= 0) {
        errors++;
        print('❌ ERROR: Platform $i has invalid size: ${p.size}');
        continue;
      }

      // ✅ Check minimum thickness
      if (p.size.y < GameConfig.minimumPlatformThickness) {
        warnings++;
        DebugConfig.logPlatformWarning(
            'Platform $i is too thin (${p.size.y}px < ${GameConfig.minimumPlatformThickness}px)'
        );
      }

      // ✅ Check landing zone width (except ground)
      if (p.layer > 0 && p.size.x < GameConfig.minimumLandingZoneWidth) {
        warnings++;
        DebugConfig.logPlatformWarning(
            'Platform $i landing zone too narrow (${p.size.x}px < ${GameConfig.minimumLandingZoneWidth}px)'
        );
      }

      // Check bounds
      if (p.position.x < 0 || p.position.x > config.width ||
          p.position.y < 0 || p.position.y > config.height) {
        warnings++;
        DebugConfig.logPlatformWarning('Platform $i out of bounds: ${p.position}');
      }
    }

    // ✅ Check vertical spacing between layers
    final layerHeights = <int, double>{};
    for (final p in platforms) {
      if (!layerHeights.containsKey(p.layer)) {
        layerHeights[p.layer] = p.position.y;
      }
    }

    final sortedLayers = layerHeights.keys.toList()..sort();
    for (int i = 0; i < sortedLayers.length - 1; i++) {
      final spacing = (layerHeights[sortedLayers[i]]! - layerHeights[sortedLayers[i + 1]]!).abs();

      if (spacing > GameConfig.maxJumpHeight) {
        warnings++;
        DebugConfig.logPlatformWarning(
            'Vertical spacing between layers ${sortedLayers[i]} and ${sortedLayers[i + 1]} '
                'exceeds max jump height ($spacing > ${GameConfig.maxJumpHeight})'
        );
      }
    }

    print('');
    print('Validation Results:');
    print('  ✅ Total Platforms: ${platforms.length}');
    print('  ⚠️  Warnings: $warnings');
    print('  ❌ Errors: $errors');

    if (errors > 0) {
      throw Exception('Map validation failed with $errors errors!');
    }

    print('✅ Validation complete');
  }

  void _ensureConnectivity() {
    print('Ensuring connectivity...');

    final graph = <int, Set<int>>{};
    for (int i = 0; i < platforms.length; i++) {
      graph[i] = {};
    }

    for (int i = 0; i < platforms.length; i++) {
      for (int j = 0; j < platforms.length; j++) {
        if (i != j && platforms[i].isReachableFrom(platforms[j])) {
          graph[i]!.add(j);
        }
      }
    }

    final visited = <int>{};
    _dfs(0, graph, visited);

    final unreachable = List.generate(platforms.length, (i) => i)
        .where((i) => !visited.contains(i))
        .toList();

    if (unreachable.isNotEmpty) {
      print('Found ${unreachable.length} unreachable platforms, adding bridges...');
      for (final platformIndex in unreachable) {
        _addBridgePlatform(platformIndex);
      }
    }
  }

  void _dfs(int node, Map<int, Set<int>> graph, Set<int> visited) {
    visited.add(node);
    for (final neighbor in graph[node]!) {
      if (!visited.contains(neighbor)) {
        _dfs(neighbor, graph, visited);
      }
    }
  }

  void _addBridgePlatform(int targetIndex) {
    final target = platforms[targetIndex];
    GeneratedPlatform? closest;
    double minDist = double.infinity;

    for (final platform in platforms) {
      if (platform == target) continue;
      final dist = (platform.position - target.position).length;
      if (dist < minDist) {
        minDist = dist;
        closest = platform;
      }
    }

    if (closest != null) {
      final midpoint = (target.position + closest.position) / 2;
      platforms.add(GeneratedPlatform(
        position: midpoint,
        size: Vector2(
          GameConfig.minimumLandingZoneWidth,
          GameConfig.minimumPlatformThickness,
        ),
        type: 'brick',
        layer: ((config.height - midpoint.y) / GameConfig.recommendedVerticalSpacing).floor(),
      ));
    }
  }

  void _placePlayerSpawn() {
    final groundPlatforms = platforms.where((p) => p.layer == 0).toList();

    if (groundPlatforms.isNotEmpty) {
      final mainPlatform = groundPlatforms.first;
      final spawnX = mainPlatform.position.x;
      final spawnY = mainPlatform.position.y - mainPlatform.size.y / 2 - 120;
      playerSpawn = Vector2(spawnX, spawnY);
    } else {
      playerSpawn = Vector2(config.width / 2, config.height - 300);
    }
  }

  void _placeChests() {
    final elevatedPlatforms = platforms.where((p) => p.layer >= 2).toList();
    elevatedPlatforms.shuffle(random);

    for (int i = 0; i < config.chestCount && i < elevatedPlatforms.length; i++) {
      final platform = elevatedPlatforms[i];
      chestPositions.add(Vector2(
        platform.position.x,
        platform.position.y - platform.size.y / 2 - 40,
      ));
    }
  }

  void _placeItems() {
    final potionCount = 3 + random.nextInt(3);
    final platformsForPotions = platforms.where((p) => p.layer >= 1).toList();
    platformsForPotions.shuffle(random);

    for (int i = 0; i < potionCount && i < platformsForPotions.length; i++) {
      final platform = platformsForPotions[i];
      itemDataList.add(ItemData(
        id: itemDataList.length,
        type: 'healthPotion',
        x: platform.position.x,
        y: platform.position.y - platform.size.y / 2 - 30,
      ));
    }

    final weaponCount = 1 + random.nextInt(2);
    final highPlatforms = platforms.where((p) => p.layer >= 3).toList();
    highPlatforms.shuffle(random);

    final weapons = Weapon.getAllWeapons();
    for (int i = 0; i < weaponCount && i < highPlatforms.length; i++) {
      final platform = highPlatforms[i];
      final weapon = weapons[random.nextInt(weapons.length)];

      itemDataList.add(ItemData(
        id: itemDataList.length,
        type: 'weapon',
        x: platform.position.x,
        y: platform.position.y - platform.size.y / 2 - 30,
        weaponId: weapon.id,
      ));
    }
  }

  // ================================================================
  // BUILD GAME MAP - FIXED COORDINATE SYSTEM
  // ================================================================

  GameMap _buildGameMap() {
    final platformDataList = <PlatformData>[];

    for (int i = 0; i < platforms.length; i++) {
      final p = platforms[i];

      // ✅ CRITICAL FIX: Store CENTER position directly (no conversion)
      platformDataList.add(PlatformData(
        id: i,
        type: p.type,
        x: p.position.x,  // Already CENTER position
        y: p.position.y,  // Already CENTER position
        width: p.size.x,
        height: p.size.y,
      ));
    }

    final chestDataList = <ChestData>[];
    for (int i = 0; i < chestPositions.length; i++) {
      chestDataList.add(ChestData(
        id: i,
        type: 'chest',
        x: chestPositions[i].x,
        y: chestPositions[i].y,
      ));
    }

    print('✅ Map generated successfully:');
    print('   - ${platforms.length} platforms');
    print('   - ${chestPositions.length} chests');
    print('   - ${itemDataList.length} items');

    return GameMap(
      name: 'procedural_${config.seed}',
      width: config.width,
      height: config.height,
      platforms: platformDataList,
      playerSpawn: SpawnPoint(x: playerSpawn!.x, y: playerSpawn!.y),
      chests: chestDataList,
      items: itemDataList,
    );
  }
}