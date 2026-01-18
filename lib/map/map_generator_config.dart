import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';

import '../chest/chest_data.dart';
import '../map/game_map.dart';

enum MapStyle {
  arena,      // Open flat arena with few platforms
  platformer, // Many vertical platforms
  dungeon,    // Enclosed rooms and corridors
  towers,     // Tall vertical structures
  chaos,      // Random mixed layout
  balanced,   // Good mix of everything
}

enum MapDifficulty {
  easy,       // Wide platforms, low heights
  medium,     // Standard platforms
  hard,       // Narrow platforms, dangerous gaps
  expert,     // Extreme parkour challenge
}

class MapGeneratorConfig {
  final MapStyle style;
  final MapDifficulty difficulty;
  final double width;
  final double height;
  final int minPlatforms;
  final int maxPlatforms;
  final int chestCount;
  final bool ensureConnectivity; // Ensure all areas are reachable
  final int seed; // For reproducible maps

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
  final int layer; // Vertical layer (0 = ground, 1 = low, 2 = mid, 3 = high)

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

  bool isReachableFrom(GeneratedPlatform other, double maxJumpHeight, double maxJumpDistance) {
    final verticalDist = (position.y - other.position.y).abs();
    final horizontalDist = (position.x - other.position.x).abs();

    // Can reach if jumping up or falling down
    if (position.y < other.position.y) {
      // Platform is higher - check if we can jump up
      return verticalDist <= maxJumpHeight && horizontalDist <= maxJumpDistance;
    } else {
      // Platform is lower - can always fall down if horizontal distance is ok
      return horizontalDist <= maxJumpDistance * 1.5; // More lenient for falling
    }
  }
}

class ProceduralMapGenerator {
  final MapGeneratorConfig config;
  late math.Random random;
  final List<GeneratedPlatform> platforms = [];
  final List<Vector2> chestPositions = [];
  Vector2? playerSpawn;

  // Jump parameters (from game mechanics)
  static const double maxJumpHeight = 300;
  static const double maxJumpDistance = 400;
  static const double playerWidth = 160;
  static const double playerHeight = 240;

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

    // Ensure connectivity if required
    if (config.ensureConnectivity) {
      _ensureConnectivity();
    }

    // Place player spawn
    _placePlayerSpawn();

    // Place chests
    _placeChests();

    // Convert to GameMap
    return _buildGameMap();
  }

  // ============= GENERATION STRATEGIES =============

  void _generateArena() {
    print('Generating Arena layout...');

    // Large ground platform
    platforms.add(GeneratedPlatform(
      position: Vector2(config.width / 2, config.height - 100),
      size: Vector2(config.width * 0.9, 60),
      type: 'ground',
      layer: 0,
    ));

    // Few elevated platforms for tactical positioning
    final platformCount = 3 + random.nextInt(3);
    for (int i = 0; i < platformCount; i++) {
      final x = config.width * (0.2 + i * 0.2);
      final y = config.height * (0.5 + random.nextDouble() * 0.2);

      platforms.add(GeneratedPlatform(
        position: Vector2(x, y),
        size: Vector2(200 + random.nextDouble() * 100, 30),
        type: 'brick',
        layer: 1,
      ));
    }
  }

  void _generatePlatformer() {
    print('Generating Platformer layout...');

    // Ground
    platforms.add(GeneratedPlatform(
      position: Vector2(config.width / 2, config.height - 50),
      size: Vector2(config.width, 40),
      type: 'ground',
      layer: 0,
    ));

    // Create ascending/descending platforms
    final layers = 4;
    final platformsPerLayer = 3 + random.nextInt(3);

    for (int layer = 1; layer <= layers; layer++) {
      final y = config.height - 200 - (layer * 200);

      for (int i = 0; i < platformsPerLayer; i++) {
        final x = (config.width / (platformsPerLayer + 1)) * (i + 1);
        final width = _getPlatformWidth();

        platforms.add(GeneratedPlatform(
          position: Vector2(x + random.nextDouble() * 100 - 50, y),
          size: Vector2(width, 30),
          type: i % 2 == 0 ? 'brick' : 'ground',
          layer: layer,
        ));
      }
    }
  }

  void _generateDungeon() {
    print('Generating Dungeon layout...');

    // Create rooms connected by corridors
    final rooms = <Rect>[];
    final roomCount = 4 + random.nextInt(3);

    for (int i = 0; i < roomCount; i++) {
      final roomWidth = 300.0 + random.nextDouble() * 200;
      final roomHeight = 200.0 + random.nextDouble() * 150;
      final x = 200 + random.nextDouble() * (config.width - roomWidth - 400);
      final y = 200 + random.nextDouble() * (config.height - roomHeight - 400);

      final room = Rect.fromLTWH(x, y, roomWidth, roomHeight);

      // Check if room overlaps with existing rooms
      if (!rooms.any((r) => _rectsOverlap(r, room))) {
        rooms.add(room);
        _createRoom(room, i);
      }
    }

    // Connect rooms with corridors
    for (int i = 0; i < rooms.length - 1; i++) {
      _connectRooms(rooms[i], rooms[i + 1]);
    }
  }

  void _generateTowers() {
    print('Generating Towers layout...');

    // Ground
    platforms.add(GeneratedPlatform(
      position: Vector2(config.width / 2, config.height - 50),
      size: Vector2(config.width, 40),
      type: 'ground',
      layer: 0,
    ));

    // Create vertical towers
    final towerCount = 3 + random.nextInt(2);
    final towerSpacing = config.width / (towerCount + 1);

    for (int t = 0; t < towerCount; t++) {
      final towerX = towerSpacing * (t + 1);
      final towerHeight = 4 + random.nextInt(3);

      for (int h = 0; h < towerHeight; h++) {
        final y = config.height - 200 - (h * 150);
        platforms.add(GeneratedPlatform(
          position: Vector2(towerX, y),
          size: Vector2(_getPlatformWidth(), 30),
          type: 'brick',
          layer: h + 1,
        ));
      }
    }
  }

  void _generateChaos() {
    print('Generating Chaos layout...');

    // Ground
    platforms.add(GeneratedPlatform(
      position: Vector2(config.width / 2, config.height - 50),
      size: Vector2(config.width * 0.8, 40),
      type: 'ground',
      layer: 0,
    ));

    // Completely random platforms
    final platformCount = config.minPlatforms +
        random.nextInt(config.maxPlatforms - config.minPlatforms);

    int attempts = 0;
    while (platforms.length < platformCount && attempts < platformCount * 5) {
      final x = 200 + random.nextDouble() * (config.width - 400);
      final y = 200 + random.nextDouble() * (config.height - 400);
      final width = _getPlatformWidth();

      final newPlatform = GeneratedPlatform(
        position: Vector2(x, y),
        size: Vector2(width, 30),
        type: random.nextBool() ? 'brick' : 'ground',
        layer: ((config.height - y) / 200).floor(),
      );

      // Check if it overlaps
      if (!platforms.any((p) => p.overlaps(newPlatform))) {
        platforms.add(newPlatform);
      }

      attempts++;
    }
  }

  void _generateBalanced() {
    print('Generating Balanced layout...');

    // Ground platform
    platforms.add(GeneratedPlatform(
      position: Vector2(config.width / 2, config.height - 50),
      size: Vector2(config.width * 0.85, 40),
      type: 'ground',
      layer: 0,
    ));

    // Lower level platforms (easy to reach)
    _addPlatformLayer(
      y: config.height - 250,
      count: 4,
      layer: 1,
      width: 200,
    );

    // Middle level platforms
    _addPlatformLayer(
      y: config.height - 450,
      count: 3,
      layer: 2,
      width: 180,
    );

    // Upper level platforms (challenge)
    _addPlatformLayer(
      y: config.height - 650,
      count: 2,
      layer: 3,
      width: 150,
    );

    // Add some random platforms for variety
    for (int i = 0; i < 3; i++) {
      final x = 300 + random.nextDouble() * (config.width - 600);
      final y = 300 + random.nextDouble() * (config.height - 600);

      final newPlatform = GeneratedPlatform(
        position: Vector2(x, y),
        size: Vector2(_getPlatformWidth(), 30),
        type: 'brick',
        layer: ((config.height - y) / 200).floor(),
      );

      if (!platforms.any((p) => p.overlaps(newPlatform))) {
        platforms.add(newPlatform);
      }
    }
  }

  // ============= HELPER METHODS =============

  void _addPlatformLayer({
    required double y,
    required int count,
    required int layer,
    required double width,
  }) {
    final spacing = config.width / (count + 1);

    for (int i = 0; i < count; i++) {
      final x = spacing * (i + 1);
      final offset = (random.nextDouble() - 0.5) * 100;

      platforms.add(GeneratedPlatform(
        position: Vector2(x + offset, y),
        size: Vector2(width + random.nextDouble() * 50 - 25, 30),
        type: i % 2 == 0 ? 'brick' : 'ground',
        layer: layer,
      ));
    }
  }

  void _createRoom(Rect room, int index) {
    // Floor
    platforms.add(GeneratedPlatform(
      position: Vector2(room.center.dx, room.bottom - 20),
      size: Vector2(room.width, 40),
      type: 'ground',
      layer: 0,
    ));

    // Optional elevated platform inside room
    if (random.nextDouble() > 0.5) {
      platforms.add(GeneratedPlatform(
        position: Vector2(room.center.dx, room.center.dy),
        size: Vector2(room.width * 0.4, 30),
        type: 'brick',
        layer: 1,
      ));
    }
  }

  void _connectRooms(Rect room1, Rect room2) {
    final x1 = room1.center.dx;
    final y1 = room1.bottom - 20;
    final x2 = room2.center.dx;
    final y2 = room2.bottom - 20;

    // Create corridor platforms
    final steps = ((x2 - x1).abs() / 200).ceil();
    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      final x = x1 + (x2 - x1) * t;
      final y = y1 + (y2 - y1) * t;

      platforms.add(GeneratedPlatform(
        position: Vector2(x, y),
        size: Vector2(180, 30),
        type: 'brick',
        layer: 1,
      ));
    }
  }

  bool _rectsOverlap(Rect a, Rect b) {
    return a.overlaps(b);
  }

  double _getPlatformWidth() {
    switch (config.difficulty) {
      case MapDifficulty.easy:
        return 200 + random.nextDouble() * 100; // 200-300
      case MapDifficulty.medium:
        return 150 + random.nextDouble() * 100; // 150-250
      case MapDifficulty.hard:
        return 120 + random.nextDouble() * 80;  // 120-200
      case MapDifficulty.expert:
        return 100 + random.nextDouble() * 50;  // 100-150
    }
  }

  void _ensureConnectivity() {
    print('Ensuring connectivity...');

    // Build connectivity graph
    final graph = <int, Set<int>>{};
    for (int i = 0; i < platforms.length; i++) {
      graph[i] = {};
    }

    // Find which platforms are reachable from each other
    for (int i = 0; i < platforms.length; i++) {
      for (int j = 0; j < platforms.length; j++) {
        if (i != j && platforms[i].isReachableFrom(platforms[j], maxJumpHeight, maxJumpDistance)) {
          graph[i]!.add(j);
        }
      }
    }

    // Find unreachable platforms and add bridges
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

    // Find closest reachable platform
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
      // Add intermediate platform
      final midpoint = (target.position + closest.position) / 2;
      platforms.add(GeneratedPlatform(
        position: midpoint,
        size: Vector2(180, 30),
        type: 'brick',
        layer: ((config.height - midpoint.y) / 200).floor(),
      ));
    }
  }

  void _placePlayerSpawn() {
    // Spawn on ground level, left side
    final groundPlatforms = platforms.where((p) => p.layer == 0).toList();
    if (groundPlatforms.isNotEmpty) {
      final spawn = groundPlatforms.first;
      playerSpawn = Vector2(
        spawn.position.x - spawn.size.x / 2 + 200,
        spawn.position.y - spawn.size.y / 2 - playerHeight / 2,
      );
    } else {
      playerSpawn = Vector2(200, config.height - 300);
    }

    print('Player spawn: ${playerSpawn!.x.toInt()}, ${playerSpawn!.y.toInt()}');
  }

  void _placeChests() {
    print('Placing ${config.chestCount} chests...');

    // Place chests on elevated platforms (reward exploration)
    final elevatedPlatforms = platforms.where((p) => p.layer >= 2).toList();
    elevatedPlatforms.shuffle(random);

    for (int i = 0; i < config.chestCount && i < elevatedPlatforms.length; i++) {
      final platform = elevatedPlatforms[i];
      chestPositions.add(Vector2(
        platform.position.x,
        platform.position.y - platform.size.y / 2 - 40,
      ));
    }

    print('Placed ${chestPositions.length} chests');
  }

  GameMap _buildGameMap() {
    final platformDataList = <PlatformData>[];

    for (int i = 0; i < platforms.length; i++) {
      final p = platforms[i];
      platformDataList.add(PlatformData(
        id: i,
        type: p.type,
        x: p.position.x,
        y: p.position.y,
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

    print('✅ Map generated: ${platforms.length} platforms, ${chestPositions.length} chests');

    return GameMap(
      name: 'procedural_${config.seed}',
      width: config.width,
      height: config.height,
      platforms: platformDataList,
      playerSpawn: SpawnPoint(
        x: playerSpawn!.x,
        y: playerSpawn!.y,
      ),
      chests: chestDataList,
    );
  }
}