import 'dart:math' as math;
import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

/// Manages infinite scrolling world with chunk-based generation
/// Features:
/// - Lazy chunk generation and unloading
/// - Circular buffer to reuse chunk objects
/// - Deterministic generation via seeds
/// - Automatic wave spawning
/// - Camera-based culling
class InfiniteMapManager {
  final ActionGame game;

  // Chunk configuration
  static const double chunkWidth = 2400.0;
  static const int activeChunks = 5; // Keep 5 chunks loaded (2 left, current, 2 right)
  static const int maxCachedChunks = 10; // Maximum chunks to keep in memory

  // Active chunks (circular buffer)
  final Map<int, WorldChunk> _activeChunks = {};
  int _currentChunkIndex = 0;
  int _lastLoadedChunk = -999;
  int _firstLoadedChunk = 999;

  // Wave generation
  final math.Random _random = math.Random();
  int _totalWavesSpawned = 0;
  double _distanceTraveled = 0;

  // Chunk factory pool
  final List<WorldChunk> _chunkPool = [];
  static const int poolPrewarmSize = 5;

  // Generation cache (prevents regenerating same chunk twice)
  final Map<int, List<Vector2>> _platformCache = {};
  final Map<int, List<WaveConfig>> _waveCache = {};

  // Seeded generation
  late final int mapSeed;
  late final math.Random seedRandom;

  // Performance tracking
  int _totalChunksGenerated = 0;
  int _totalChunksUnloaded = 0;
  double _lastUpdateTime = 0;

  InfiniteMapManager({
    required this.game,
    int? seed,
  }) {
    mapSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
    seedRandom = math.Random(mapSeed);
    _prewarmChunkPool();
  }

  /// Pre-create chunk objects for faster pooling
  void _prewarmChunkPool() {
    for (int i = 0; i < poolPrewarmSize; i++) {
      _chunkPool.add(WorldChunk.empty());
    }
    print('✅ InfiniteMapManager: Prewarm pool ($poolPrewarmSize chunks)');
  }

  /// Initialize the infinite map
  void initialize() {
    print('🗺️  Initializing infinite map system (seed: $mapSeed)...');

    // Generate initial chunks
    for (int i = -2; i <= 2; i++) {
      _loadChunk(i);
    }

    print('✅ Infinite map initialized with ${_activeChunks.length} chunks');
  }

  /// Update based on player position
  void update(Vector2 playerPosition, double dt) {
    _lastUpdateTime = dt;

    // Calculate which chunk player is in
    final chunkIndex = (playerPosition.x / chunkWidth).floor();

    // Track distance
    _distanceTraveled = playerPosition.x;

    // Check if we need to generate new chunks
    if (chunkIndex != _currentChunkIndex) {
      _onChunkTransition(chunkIndex);
      _currentChunkIndex = chunkIndex;
    }

    // Update chunk visibility
    _updateChunkCulling(playerPosition);
  }

  /// Handle chunk transition
  void _onChunkTransition(int newChunkIndex) {
    print('🏃 Player transitioned to chunk $newChunkIndex');

    // Load chunks around new position
    for (int i = newChunkIndex - 2; i <= newChunkIndex + 2; i++) {
      _loadChunk(i);
    }

    // Check if current chunk has a pending wave
    final currentChunk = _activeChunks[newChunkIndex];
    if (currentChunk != null && currentChunk.shouldSpawnWave && !currentChunk.waveSpawned) {
      _spawnWaveInChunk(currentChunk);
      currentChunk.waveSpawned = true;
      _totalWavesSpawned++;
    }

    // Unload distant chunks (memory optimization)
    _unloadDistantChunks(newChunkIndex);
  }

  /// Load or create a chunk
  void _loadChunk(int chunkIndex) {
    // Already loaded
    if (_activeChunks.containsKey(chunkIndex)) {
      return;
    }

    // Track boundaries
    _firstLoadedChunk = math.min(_firstLoadedChunk, chunkIndex);
    _lastLoadedChunk = math.max(_lastLoadedChunk, chunkIndex);

    // Create/retrieve chunk from pool
    final chunk = _getChunkFromPool()
      ..reset(
        index: chunkIndex,
        startX: chunkIndex * chunkWidth,
        width: chunkWidth,
      );

    // Generate content deterministically
    _generateChunkContent(chunk);

    // Add platforms to game world
    _addChunkPlatformsToWorld(chunk);

    _activeChunks[chunkIndex] = chunk;
    _totalChunksGenerated++;

    print('📦 Generated chunk $chunkIndex '
        '(${chunk.startX.toInt()} - ${(chunk.startX + chunk.width).toInt()})');
  }

  /// Get chunk from pool or create new one
  WorldChunk _getChunkFromPool() {
    if (_chunkPool.isNotEmpty) {
      return _chunkPool.removeLast();
    }
    return WorldChunk.empty();
  }

  /// Return chunk to pool
  void _returnChunkToPool(WorldChunk chunk) {
    chunk.clearResources();
    if (_chunkPool.length < maxCachedChunks) {
      _chunkPool.add(chunk);
    }
  }

  /// Generate platforms and waves for chunk using deterministic seeding
  void _generateChunkContent(WorldChunk chunk) {
    // Use chunk-specific seed for deterministic generation
    final chunkSeed = mapSeed + chunk.index;
    final chunkRandom = math.Random(chunkSeed);

    // Check cache first
    if (!_platformCache.containsKey(chunk.index)) {
      _platformCache[chunk.index] = _generatePlatformsForChunk(chunk, chunkRandom);
    }
    chunk.platformData = _platformCache[chunk.index]!;

    if (!_waveCache.containsKey(chunk.index)) {
      _waveCache[chunk.index] = _generateWaveConfigForChunk(chunk, chunkRandom);
    }
    chunk.waveConfigs = _waveCache[chunk.index]!;

    // Determine if this chunk spawns a wave
    _determineWaveSpawn(chunk, chunkRandom);
  }

  /// Generate platform positions for a chunk
  List<Vector2> _generatePlatformsForChunk(WorldChunk chunk, math.Random random) {
    final platforms = <Vector2>[];

    // Ground platform (always present)
    platforms.add(Vector2(chunk.centerX, 1000));

    // Generate floating platforms
    final platformCount = 3 + random.nextInt(4);
    for (int i = 0; i < platformCount; i++) {
      final x = chunk.startX + 200 + random.nextDouble() * (chunk.width - 400);
      final y = 300 + random.nextDouble() * 500;

      // Avoid clusters at same height
      final isClustered = platforms.any((p) => (p.y - y).abs() < 50);
      if (!isClustered || random.nextDouble() < 0.3) {
        platforms.add(Vector2(x, y));
      }
    }

    return platforms;
  }

  /// Generate wave configurations for chunk
  List<WaveConfig> _generateWaveConfigForChunk(
      WorldChunk chunk, math.Random random) {
    if (chunk.index <= 0 || chunk.index % 2 != 0) {
      return []; // Only even chunks spawn waves
    }

    final configs = <WaveConfig>[];

    final waveNumber = chunk.index ~/ 2;
    final difficulty = 1.0 + (chunk.index * 0.15);

    // Base enemy count
    final baseCount = 2 + (waveNumber ~/ 3);
    final enemyCount = baseCount.clamp(2, 8);

    // Determine enemy composition
    final enemyTypes = _selectEnemyComposition(waveNumber, random);

    configs.add(WaveConfig(
      waveNumber: waveNumber,
      spawnX: chunk.centerX,
      spawnY: 600.0,
      enemyCount: enemyCount,
      enemyTypes: enemyTypes,
      difficulty: difficulty,
      isBossWave: waveNumber % 5 == 0,
    ));

    return configs;
  }

  /// Select enemy types based on wave progression
  List<String> _selectEnemyComposition(int waveNumber, math.Random random) {
    final types = <String>[];
    final availableTypes = <String>['knight', 'thief', 'wizard', 'trader'];

    // Remove unavailable types for early waves
    if (waveNumber < 2) availableTypes.remove('thief');
    if (waveNumber < 3) availableTypes.remove('wizard');
    if (waveNumber < 4) availableTypes.remove('trader');

    final enemyCount = 2 + (waveNumber ~/ 3);
    for (int i = 0; i < enemyCount; i++) {
      types.add(availableTypes[random.nextInt(availableTypes.length)]);
    }

    return types;
  }

  /// Determine if chunk should spawn a wave
  void _determineWaveSpawn(WorldChunk chunk, math.Random random) {
    if (chunk.index <= 0 || chunk.index % 2 != 0) {
      chunk.shouldSpawnWave = false;
      return;
    }

    chunk.shouldSpawnWave = true;
    chunk.waveSpawnX = chunk.centerX;

    final waveNumber = chunk.index ~/ 2;
    chunk.waveNumber = waveNumber;
    chunk.waveDifficulty = 1.0 + (chunk.index * 0.15);

    print('⚔️  Chunk ${chunk.index} will spawn wave #$waveNumber '
        '(difficulty: ${chunk.waveDifficulty.toStringAsFixed(1)}x)');
  }

  /// Add chunk platforms to game world
  void _addChunkPlatformsToWorld(WorldChunk chunk) {
    // Create platform objects from cached data
    for (int i = 0; i < chunk.platformData.length; i++) {
      final pos = chunk.platformData[i];
      final width = i == 0 ? chunk.width : (150.0 + _random.nextDouble() * 150);
      final height = i == 0 ? 60.0 : 30.0;
      final platformType = i == 0 ? 'ground' : (_random.nextBool() ? 'brick' : 'ground');

      final platform = TiledPlatform(
        position: pos,
        size: Vector2(width, height),
        platformType: platformType,
      );
      platform.priority = 10;

      game.add(platform);
      game.world.add(platform);
      game.platforms.add(platform);
      chunk.platformRefs.add(platform);
    }
  }

  /// Spawn wave in chunk
  void _spawnWaveInChunk(WorldChunk chunk) {
    if (chunk.waveConfigs.isEmpty) return;

    final config = chunk.waveConfigs.first;

    print('\n╔════════════════════════════════════╗');
    print('║   WAVE ${config.waveNumber} APPROACHING!    ║');
    print('╚════════════════════════════════════╝');
    print('Location: ${config.spawnX.toInt()}');
    print('Difficulty: ${config.difficulty.toStringAsFixed(1)}x');
    print('Enemies: ${config.enemyCount}\n');

    // Spawn enemies with staggered timing
    for (int i = 0; i < config.enemyCount; i++) {
      final enemyType = config.enemyTypes[i % config.enemyTypes.length];
      final spawnX = config.spawnX + (i - config.enemyCount / 2) * 150;
      final spawnY = config.spawnY;

      // Stagger spawning
      Future.delayed(Duration(milliseconds: i * 500), () {
        _spawnEnemyAtPosition(enemyType, Vector2(spawnX, spawnY), config);
      });
    }

    // Emit wave event
    game.eventBus.emit(WaveStartedEvent(
      waveNumber: config.waveNumber,
      enemyCount: config.enemyCount,
      enemyTypes: config.enemyTypes,
      difficultyMultiplier: config.difficulty,
    ));
  }

  /// Spawn individual enemy
  void _spawnEnemyAtPosition(String enemyType, Vector2 position, WaveConfig config) {
    game.eventBus.emit(EnemySpawnedEvent(
      enemyId: 'enemy_${DateTime.now().millisecondsSinceEpoch}',
      enemyType: enemyType,
      spawnPosition: position,
      waveNumber: config.waveNumber,
    ));
  }

  /// Update chunk visibility and rendering
  void _updateChunkCulling(Vector2 playerPosition) {
    // Calculate visible area (with margin)
    const cullingMargin = 1500.0;
    final visibleMinX = playerPosition.x - cullingMargin;
    final visibleMaxX = playerPosition.x + game.size.x + cullingMargin;

    for (final chunk in _activeChunks.values) {
      final isVisible = chunk.endX > visibleMinX && chunk.startX < visibleMaxX;

      // Enable/disable rendering
      for (final platform in chunk.platformRefs) {
        platform.priority = isVisible ? 10 : -1;
      }
    }
  }

  /// Unload chunks that are too far away
  void _unloadDistantChunks(int currentIndex) {
    final chunksToRemove = <int>[];

    _activeChunks.forEach((index, chunk) {
      final distance = (index - currentIndex).abs();

      if (distance > 3) {
        chunksToRemove.add(index);

        // Remove platforms from game
        for (final platform in chunk.platformRefs) {
          platform.removeFromParent();
          game.platforms.remove(platform);
        }

        // Return chunk to pool
        _returnChunkToPool(chunk);
        _totalChunksUnloaded++;
      }
    });

    for (final index in chunksToRemove) {
      _activeChunks.remove(index);
      print('🗑️  Unloaded chunk $index');
    }
  }

  /// Get all active platforms in range
  List<TiledPlatform> getPlatformsInRange(Vector2 position, double range) {
    final result = <TiledPlatform>[];

    for (final chunk in _activeChunks.values) {
      for (final platform in chunk.platformRefs) {
        if (position.distanceTo(platform.position) < range) {
          result.add(platform);
        }
      }
    }

    return result;
  }

  /// Force load a specific chunk
  void forceLoadChunk(int chunkIndex) {
    if (!_activeChunks.containsKey(chunkIndex)) {
      _loadChunk(chunkIndex);
    }
  }

  /// Clear all loaded chunks
  void clearAllChunks() {
    for (final chunk in _activeChunks.values) {
      for (final platform in chunk.platformRefs) {
        platform.removeFromParent();
        game.platforms.remove(platform);
      }
      _returnChunkToPool(chunk);
    }
    _activeChunks.clear();
    _platformCache.clear();
    _waveCache.clear();
    print('🧹 All chunks cleared');
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'totalWavesSpawned': _totalWavesSpawned,
      'totalChunksGenerated': _totalChunksGenerated,
      'totalChunksUnloaded': _totalChunksUnloaded,
      'distanceTraveled': _distanceTraveled.toInt(),
      'activeChunks': _activeChunks.length,
      'totalPlatforms': _activeChunks.values.fold<int>(
          0, (sum, chunk) => sum + chunk.platformRefs.length),
      'currentChunk': _currentChunkIndex,
      'chunkPoolSize': _chunkPool.length,
      'lastUpdateTime': _lastUpdateTime.toStringAsFixed(3),
    };
  }

  void printStats() {
    final stats = getStats();
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🗺️  INFINITE MAP STATISTICS');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Map Seed: $mapSeed');
    print('Total Chunks Generated: ${stats['totalChunksGenerated']}');
    print('Active Chunks: ${stats['activeChunks']}');
    print('Total Platforms: ${stats['totalPlatforms']}');
    print('Waves Spawned: ${stats['totalWavesSpawned']}');
    print('Distance Traveled: ${stats['distanceTraveled']}px');
    print('Chunk Pool Size: ${stats['chunkPoolSize']}');
    print('Last Update: ${stats['lastUpdateTime']}ms');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  /// Get active chunks (for debug visualization)
  /// Get all loaded chunks
  Map<int, WorldChunk> get loadedChunks => _activeChunks;

  /// Get current chunk index
  int get currentChunkIndex => _currentChunkIndex;

  /// Get total waves spawned
  int get totalWavesSpawned => _totalWavesSpawned;

  /// Get distance traveled
  double get distanceTraveled => _distanceTraveled;

  /// Get total chunks generated
  int get totalChunksGenerated => _totalChunksGenerated;

  void dispose() {
    clearAllChunks();
    _chunkPool.clear();
    print('🗑️  InfiniteMapManager disposed');
  }
}
