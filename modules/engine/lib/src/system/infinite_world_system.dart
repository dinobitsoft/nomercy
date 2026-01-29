import 'dart:math' as math;
import 'dart:ui';

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

/// Manages infinite scrolling world with chunk-based generation and wave spawning
class InfiniteWorldSystem {
  final ActionGame game;

  // ==========================================
  // CHUNK MANAGEMENT
  // ==========================================
  static const double chunkWidth = 2400.0;
  static const int activeChunks = 5; // Circular buffer size

  final Map<int, WorldChunk> _activeChunks = {};
  final List<WorldChunk> _chunkPool = []; // Reuse chunks
  int _currentChunkIndex = 0;
  int _nextChunkId = 0;

  // ==========================================
  // WAVE SPAWNING
  // ==========================================
  int _totalWavesSpawned = 0;
  double _distanceTraveled = 0;
  final Map<int, WaveZone> _activeWaveZones = {};

  // ==========================================
  // CULLING & OPTIMIZATION
  // ==========================================
  final Set<TiledPlatform> _visiblePlatforms = {};
  final Set<GameCharacter> _visibleEnemies = {};
  double _cullDistance = 3000.0;

  // ==========================================
  // STATISTICS
  // ==========================================
  int _chunksGenerated = 0;
  int _chunksReused = 0;
  int _platformsCulled = 0;

  final math.Random _random = math.Random();

  InfiniteWorldSystem({required this.game});

  /// Initialize infinite world
  void initialize() {
    print('🌍 Initializing Infinite World System...');

    // Pre-generate chunk pool
    for (int i = 0; i < activeChunks * 2; i++) {
      _chunkPool.add(_createEmptyChunk());
    }

    // Generate initial chunks around spawn
    for (int i = -2; i <= 2; i++) {
      _generateChunk(i);
    }

    print('✅ Infinite World initialized');
    print('   - Chunk pool: ${_chunkPool.length}');
    print('   - Active chunks: ${_activeChunks.length}');
  }

  /// Update based on player position (call every frame)
  void update(double dt, Vector2 playerPosition) {
    // Calculate current chunk
    final chunkIndex = (playerPosition.x / chunkWidth).floor();

    // Track distance
    _distanceTraveled = playerPosition.x;

    // Generate new chunks if player moved
    if (chunkIndex != _currentChunkIndex) {
      _onChunkTransition(chunkIndex);
      _currentChunkIndex = chunkIndex;
    }

    // Update culling based on camera
    _updateCulling(playerPosition);

    // Update active wave zones
    _updateWaveZones(dt, playerPosition);
  }

  // ==========================================
  // CHUNK GENERATION
  // ==========================================

  void _generateChunk(int chunkIndex) {
    if (_activeChunks.containsKey(chunkIndex)) return;

    // Try to reuse chunk from pool
    final chunk = _chunkPool.isNotEmpty
        ? _reuseChunk(chunkIndex)
        : _createNewChunk(chunkIndex);

    _activeChunks[chunkIndex] = chunk;
    _generatePlatformsForChunk(chunk);
    _checkWaveSpawn(chunk);

    print('📦 Chunk $chunkIndex ready (${chunk.platforms.length} platforms)');
  }

  WorldChunk _reuseChunk(int chunkIndex) {
    final chunk = _chunkPool.removeLast();
    chunk.reset(
      index: chunkIndex,
      startX: chunkIndex * chunkWidth,
    );
    _chunksReused++;
    return chunk;
  }

  WorldChunk _createNewChunk(int chunkIndex) {
    _chunksGenerated++;
    return WorldChunk(
      id: _nextChunkId++,
      index: chunkIndex,
      startX: chunkIndex * chunkWidth,
      width: chunkWidth,
    );
  }

  WorldChunk _createEmptyChunk() {
    return WorldChunk(
      id: _nextChunkId++,
      index: 0,
      startX: 0,
      width: chunkWidth,
    );
  }

  void _generatePlatformsForChunk(WorldChunk chunk) {
    // Ground platform (always present)
    final groundPlatform = TiledPlatform(
      position: Vector2(chunk.centerX, 1000),
      size: Vector2(chunk.width, 60),
      platformType: 'ground',
    );
    groundPlatform.priority = 10;

    chunk.platforms.add(groundPlatform);
    game.world.add(groundPlatform);
    game.platforms.add(groundPlatform);

    // Procedural floating platforms (3-6 per chunk)
    final platformCount = 3 + _random.nextInt(4);

    for (int i = 0; i < platformCount; i++) {
      final x = chunk.startX + 200 + _random.nextDouble() * (chunk.width - 400);
      final y = 400 + _random.nextDouble() * 400;
      final width = 120.0 + _random.nextDouble() * 150;

      final platform = TiledPlatform(
        position: Vector2(x, y),
        size: Vector2(width, 30),
        platformType: _random.nextBool() ? 'brick' : 'ground',
      );
      platform.priority = 10;

      chunk.platforms.add(platform);
      game.world.add(platform);
      game.platforms.add(platform);
    }
  }

  // ==========================================
  // WAVE SPAWNING
  // ==========================================

  void _checkWaveSpawn(WorldChunk chunk) {
    // Spawn wave every 2-3 chunks
    if (chunk.index > 0 && chunk.index % 2 == 0) {
      final zone = WaveZone(
        chunkIndex: chunk.index,
        spawnX: chunk.centerX,
        waveNumber: _totalWavesSpawned + 1,
        difficulty: 1.0 + (chunk.index * 0.1),
        enemyCount: _calculateEnemyCount(chunk.index),
      );

      _activeWaveZones[chunk.index] = zone;
      print('⚔️  Wave zone prepared at chunk ${chunk.index}');
    }
  }

  int _calculateEnemyCount(int chunkIndex) {
    final base = 2;
    final bonus = (chunkIndex / 3).floor();
    return (base + bonus).clamp(2, 8);
  }

  void _updateWaveZones(double dt, Vector2 playerPosition) {
    final zonesToTrigger = <int>[];

    _activeWaveZones.forEach((chunkIndex, zone) {
      // Check if player entered zone
      if (!zone.triggered) {
        final distanceToZone = (playerPosition.x - zone.spawnX).abs();

        if (distanceToZone < chunkWidth * 0.5) {
          zonesToTrigger.add(chunkIndex);
        }
      }
    });

    // Trigger waves
    for (final chunkIndex in zonesToTrigger) {
      _triggerWave(_activeWaveZones[chunkIndex]!);
    }
  }

  void _triggerWave(WaveZone zone) {
    zone.triggered = true;
    _totalWavesSpawned++;

    print('\n╔════════════════════════════════════╗');
    print('║   WAVE ${zone.waveNumber} TRIGGERED!        ║');
    print('╚════════════════════════════════════╝');
    print('Location: ${zone.spawnX.toInt()}');
    print('Enemies: ${zone.enemyCount}');
    print('Difficulty: ${zone.difficulty.toStringAsFixed(1)}x\n');

    // Spawn enemies
    _spawnWaveEnemies(zone);

    // Visual notification
    game.eventBus.emit(ShowNotificationEvent(
      message: '⚠️ WAVE ${zone.waveNumber}!',
      color: const Color(0xFFFF4444),
      duration: const Duration(seconds: 2),
    ));
  }

  void _spawnWaveEnemies(WaveZone zone) {
    final enemyTypes = ['knight', 'thief', 'wizard', 'trader'];

    for (int i = 0; i < zone.enemyCount; i++) {
      final enemyType = enemyTypes[_random.nextInt(enemyTypes.length)];
      final spawnX = zone.spawnX + (i - zone.enemyCount / 2) * 150;
      final spawnY = 600.0;

      // Delayed spawn for dramatic effect
      Future.delayed(Duration(milliseconds: i * 300), () {
        if (!game.isGameOver) {
          _spawnEnemy(
            enemyType: enemyType,
            position: Vector2(spawnX, spawnY),
            difficultyMultiplier: zone.difficulty,
          );
        }
      });
    }
  }

  void _spawnEnemy({
    required String enemyType,
    required Vector2 position,
    required double difficultyMultiplier,
  }) {
    // Create enemy with appropriate tactic
    final tactics = [
      AggressiveTactic(),
      BalancedTactic(),
      DefensiveTactic(),
      TacticalTactic(),
    ];
    final randomTactic = tactics[_random.nextInt(tactics.length)];

    GameCharacter enemy;
    switch (enemyType.toLowerCase()) {
      case 'knight':
        enemy = Knight(
          position: position,
          playerType: PlayerType.bot,
          botTactic: randomTactic,
        );
        break;
      case 'thief':
        enemy = Thief(
          position: position,
          playerType: PlayerType.bot,
          botTactic: randomTactic,
        );
        break;
      case 'wizard':
        enemy = Wizard(
          position: position,
          playerType: PlayerType.bot,
          botTactic: randomTactic,
        );
        break;
      case 'trader':
        enemy = Trader(
          position: position,
          playerType: PlayerType.bot,
          botTactic: randomTactic,
        );
        break;
      default:
        enemy = Knight(
          position: position,
          playerType: PlayerType.bot,
          botTactic: randomTactic,
        );
    }

    // Scale difficulty
    enemy.characterState.health *= difficultyMultiplier;
    enemy.stats.attackDamage *= difficultyMultiplier;

    enemy.priority = 90;
    game.add(enemy);
    game.world.add(enemy);
    game.enemies.add(enemy);
  }

  // ==========================================
  // CHUNK TRANSITION
  // ==========================================

  void _onChunkTransition(int newChunkIndex) {
    print('🏃 Player entered chunk $newChunkIndex');

    // Generate chunks ahead
    for (int i = newChunkIndex - 2; i <= newChunkIndex + 2; i++) {
      _generateChunk(i);
    }

    // Unload distant chunks
    _unloadDistantChunks(newChunkIndex);
  }

  void _unloadDistantChunks(int currentIndex) {
    final chunksToRemove = <int>[];

    _activeChunks.forEach((index, chunk) {
      final distance = (index - currentIndex).abs();

      if (distance > 3) {
        chunksToRemove.add(index);
      }
    });

    for (final index in chunksToRemove) {
      final chunk = _activeChunks.remove(index)!;
      _recycleChunk(chunk);
    }
  }

  void _recycleChunk(WorldChunk chunk) {
    // Remove all platforms from game
    for (final platform in chunk.platforms) {
      platform.removeFromParent();
      game.platforms.remove(platform);
      _visiblePlatforms.remove(platform);
    }

    // Clear chunk data
    chunk.platforms.clear();
    chunk.waveSpawned = false;

    // Return to pool
    _chunkPool.add(chunk);

    print('♻️  Recycled chunk ${chunk.index}');
  }

  // ==========================================
  // CULLING SYSTEM
  // ==========================================

  void _updateCulling(Vector2 cameraPosition) {
    _cullPlatforms(cameraPosition);
    _cullEnemies(cameraPosition);
  }

  void _cullPlatforms(Vector2 cameraPosition) {
    int culledCount = 0;

    for (final platform in game.platforms) {
      final distance = (platform.position - cameraPosition).length;
      final shouldBeVisible = distance < _cullDistance;

      if (shouldBeVisible && !_visiblePlatforms.contains(platform)) {
        // Make visible
        platform.priority = 10;
        _visiblePlatforms.add(platform);
      } else if (!shouldBeVisible && _visiblePlatforms.contains(platform)) {
        // Cull (hide by setting very low priority)
        platform.priority = -1000;
        _visiblePlatforms.remove(platform);
        culledCount++;
      }
    }

    if (culledCount > 0) {
      _platformsCulled += culledCount;
    }
  }

  void _cullEnemies(Vector2 cameraPosition) {
    for (final enemy in game.enemies) {
      final distance = (enemy.position - cameraPosition).length;
      final shouldBeVisible = distance < _cullDistance;

      if (shouldBeVisible && !_visibleEnemies.contains(enemy)) {
        enemy.priority = 90;
        _visibleEnemies.add(enemy);
      } else if (!shouldBeVisible && _visibleEnemies.contains(enemy)) {
        // Pause distant enemies (don't remove, just lower priority)
        enemy.priority = -500;
        _visibleEnemies.remove(enemy);
      }
    }
  }

  // ==========================================
  // STATISTICS
  // ==========================================

  Map<String, dynamic> getStats() {
    return {
      'totalWaves': _totalWavesSpawned,
      'distanceTraveled': _distanceTraveled.toInt(),
      'currentChunk': _currentChunkIndex,
      'activeChunks': _activeChunks.length,
      'chunksGenerated': _chunksGenerated,
      'chunksReused': _chunksReused,
      'chunkPoolSize': _chunkPool.length,
      'visiblePlatforms': _visiblePlatforms.length,
      'visibleEnemies': _visibleEnemies.length,
      'platformsCulled': _platformsCulled,
      'activeWaveZones': _activeWaveZones.length,
    };
  }

  void printStats() {
    final stats = getStats();
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🌍 INFINITE WORLD STATISTICS');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Distance Traveled: ${stats['distanceTraveled']}m');
    print('Current Chunk: ${stats['currentChunk']}');
    print('Total Waves: ${stats['totalWaves']}');
    print('\nChunk Management:');
    print('  Active: ${stats['activeChunks']}');
    print('  Generated: ${stats['chunksGenerated']}');
    print('  Reused: ${stats['chunksReused']}');
    print('  Pool Size: ${stats['chunkPoolSize']}');
    print('\nCulling:');
    print('  Visible Platforms: ${stats['visiblePlatforms']}');
    print('  Visible Enemies: ${stats['visibleEnemies']}');
    print('  Platforms Culled: ${stats['platformsCulled']}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  void dispose() {
    _activeChunks.clear();
    _chunkPool.clear();
    _activeWaveZones.clear();
    _visiblePlatforms.clear();
    _visibleEnemies.clear();
    print('🗑️  InfiniteWorldSystem disposed');
  }
}