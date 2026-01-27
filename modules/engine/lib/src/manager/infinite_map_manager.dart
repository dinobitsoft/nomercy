import 'dart:math' as math;
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

/// Manages infinite scrolling world with chunk-based generation
class InfiniteMapManager {
  final ActionGame game;

  // Chunk configuration
  static const double chunkWidth = 2400.0; // Width of each chunk
  static const int activeChunks = 5; // Keep 5 chunks loaded (2 left, current, 2 right)

  // Chunk tracking
  final Map<int, WorldChunk> _chunks = {};
  int _currentChunkIndex = 0;

  // Wave generation
  final math.Random _random = math.Random();
  int _totalWavesSpawned = 0;
  double _distanceTraveled = 0;

  // Performance
  final Set<TiledPlatform> _activePlatforms = {};

  InfiniteMapManager({required this.game});

  /// Initialize the infinite map
  void initialize() {
    print('🗺️  Initializing infinite map system...');

    // Generate initial chunks
    for (int i = -2; i <= 2; i++) {
      _generateChunk(i);
    }

    print('✅ Infinite map initialized with ${_chunks.length} chunks');
  }

  /// Update based on player position
  void update(Vector2 playerPosition) {
    // Calculate which chunk player is in
    final chunkIndex = (playerPosition.x / chunkWidth).floor();

    // Track distance
    _distanceTraveled = playerPosition.x;

    // Check if we need to generate new chunks
    if (chunkIndex != _currentChunkIndex) {
      _onChunkChanged(chunkIndex);
      _currentChunkIndex = chunkIndex;
    }

    // Update active platforms (cull distant ones)
    _updateActivePlatforms(playerPosition);
  }

  /// Generate a new chunk at given index
  void _generateChunk(int chunkIndex) {
    if (_chunks.containsKey(chunkIndex)) return;

    final chunk = WorldChunk(
      index: chunkIndex,
      startX: chunkIndex * chunkWidth,
      width: chunkWidth,
    );

    // Generate platforms for this chunk
    _generatePlatformsForChunk(chunk);

    // Determine if this chunk should spawn a wave
    _determineWaveSpawn(chunk);

    _chunks[chunkIndex] = chunk;

    print('📦 Generated chunk $chunkIndex (${chunk.startX.toInt()} to ${(chunk.startX + chunk.width).toInt()})');
  }

  /// Generate platforms within a chunk
  void _generatePlatformsForChunk(WorldChunk chunk) {
    // Ground platform (always present)
    final groundPlatform = TiledPlatform(
      position: Vector2(chunk.startX + chunk.width / 2, 1000),
      size: Vector2(chunk.width, 60),
      platformType: 'ground',
    );
    groundPlatform.priority = 10;

    chunk.platforms.add(groundPlatform);
    game.world.add(groundPlatform);
    game.platforms.add(groundPlatform);
    _activePlatforms.add(groundPlatform);

    // Generate 3-6 floating platforms per chunk
    final platformCount = 3 + _random.nextInt(4);

    for (int i = 0; i < platformCount; i++) {
      final x = chunk.startX + 200 + _random.nextDouble() * (chunk.width - 400);
      final y = 400 + _random.nextDouble() * 400;
      final width = 150.0 + _random.nextDouble() * 150;

      final platform = TiledPlatform(
        position: Vector2(x, y),
        size: Vector2(width, 30),
        platformType: _random.nextBool() ? 'brick' : 'ground',
      );
      platform.priority = 10;

      chunk.platforms.add(platform);
      game.world.add(platform);
      game.platforms.add(platform);
      _activePlatforms.add(platform);
    }
  }

  /// Determine if a wave should spawn in this chunk
  void _determineWaveSpawn(WorldChunk chunk) {
    // Spawn wave every 2-3 chunks
    final shouldSpawn = chunk.index > 0 && chunk.index % 2 == 0;

    if (shouldSpawn) {
      chunk.shouldSpawnWave = true;
      chunk.waveSpawnX = chunk.startX + chunk.width * 0.5; // Middle of chunk
      chunk.waveNumber = _totalWavesSpawned + 1;

      // Calculate wave difficulty based on distance
      final difficulty = 1.0 + (chunk.index * 0.1);
      chunk.waveDifficulty = difficulty;

      print('⚔️  Chunk ${chunk.index} will spawn wave #${chunk.waveNumber} (difficulty: ${difficulty.toStringAsFixed(1)}x)');
    }
  }

  /// Handle chunk transition
  void _onChunkChanged(int newChunkIndex) {
    print('🏃 Player entered chunk $newChunkIndex');

    // Generate chunks ahead
    for (int i = newChunkIndex - 2; i <= newChunkIndex + 2; i++) {
      _generateChunk(i);
    }

    // Unload chunks that are too far away
    _unloadDistantChunks(newChunkIndex);

    // Check if current chunk has a wave
    final currentChunk = _chunks[newChunkIndex];
    if (currentChunk != null && currentChunk.shouldSpawnWave && !currentChunk.waveSpawned) {
      _spawnWave(currentChunk);
      currentChunk.waveSpawned = true;
      _totalWavesSpawned++;
    }
  }

  /// Spawn a wave in the given chunk
  void _spawnWave(WorldChunk chunk) {
    print('\n╔════════════════════════════════════╗');
    print('║   WAVE ${chunk.waveNumber} APPROACHING!      ║');
    print('╚════════════════════════════════════╝');
    print('Location: ${chunk.waveSpawnX.toInt()}');
    print('Difficulty: ${chunk.waveDifficulty.toStringAsFixed(1)}x');

    // Calculate enemy count (2-6 based on wave number)
    final baseEnemies = 2;
    final bonusEnemies = (chunk.waveNumber / 3).floor();
    final enemyCount = (baseEnemies + bonusEnemies).clamp(2, 6);

    print('Enemies: $enemyCount\n');

    // Spawn enemies
    final enemyTypes = ['knight', 'thief', 'wizard', 'trader'];

    for (int i = 0; i < enemyCount; i++) {
      final randomType = enemyTypes[_random.nextInt(enemyTypes.length)];

      // Spread enemies across chunk
      final spawnX = chunk.waveSpawnX + (i - enemyCount / 2) * 150;
      final spawnY = 600.0;

      // Notify game to spawn enemy
/*      game.spawnInfiniteEnemy( //TODO: should be implemented
        characterClass: randomType,
        position: Vector2(spawnX, spawnY),
        difficultyMultiplier: chunk.waveDifficulty,
      );*/
    }
  }

  /// Unload chunks that are far from player
  void _unloadDistantChunks(int currentIndex) {
    final chunksToRemove = <int>[];

    _chunks.forEach((index, chunk) {
      final distance = (index - currentIndex).abs();

      if (distance > 3) {
        chunksToRemove.add(index);

        // Remove platforms from game
        for (final platform in chunk.platforms) {
          platform.removeFromParent();
          game.platforms.remove(platform);
          _activePlatforms.remove(platform);
        }
      }
    });

    for (final index in chunksToRemove) {
      _chunks.remove(index);
      print('🗑️  Unloaded chunk $index');
    }
  }

  /// Update which platforms are active (for optimization)
  void _updateActivePlatforms(Vector2 playerPosition) {
    // This is already handled by chunk loading/unloading
    // Additional culling could be added here if needed
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'totalWavesSpawned': _totalWavesSpawned,
      'distanceTraveled': _distanceTraveled.toInt(),
      'activeChunks': _chunks.length,
      'activePlatforms': _activePlatforms.length,
      'currentChunk': _currentChunkIndex,
    };
  }

  void dispose() {
    _chunks.clear();
    _activePlatforms.clear();
    print('🗑️  InfiniteMapManager disposed');
  }
}

/// Represents a chunk of the infinite world
class WorldChunk {
  final int index;
  final double startX;
  final double width;

  final List<TiledPlatform> platforms = [];

  // Wave configuration
  bool shouldSpawnWave = false;
  bool waveSpawned = false;
  double waveSpawnX = 0;
  int waveNumber = 0;
  double waveDifficulty = 1.0;

  WorldChunk({
    required this.index,
    required this.startX,
    required this.width,
  });

  double get endX => startX + width;
  double get centerX => startX + width / 2;
}