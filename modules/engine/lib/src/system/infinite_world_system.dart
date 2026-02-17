import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

import '../components/platform/platform_factory.dart';

class InfiniteWorldSystem {
  final ActionGame game;

  // ── chunk config ─────────────────────────────────────────────────────────
  static const double chunkWidth   = 2400.0;
  static const int   activeChunks  = 5;

  // ── ground config ─────────────────────────────────────────────────────────
  // Single ground surface shared across the entire infinite world.
  // Y = vertical centre of the TiledGroundComponent tile strip.
  static const double groundCentreY = 950.0;

  // Top surface Y that characters stand on.
  static double get groundSurfaceY =>
      groundCentreY - TiledGroundComponent.tileSize / 2;

  // Spawn Y so a character's bottom edge sits exactly on the surface.
  static double spawnY(double characterHeight) =>
      groundSurfaceY - characterHeight / 2;

  // ── state ─────────────────────────────────────────────────────────────────
  TiledGroundComponent? _ground;

  final Map<int, WorldChunk> _activeChunks = {};
  final List<WorldChunk>     _chunkPool    = [];
  int _currentChunkIndex = 0;
  int _nextChunkId       = 0;

  int    _totalWavesSpawned = 0;
  double _distanceTraveled  = 0;
  final Map<int, WaveZone> _activeWaveZones = {};

  final Set<GamePlatform>  _visiblePlatforms = {};
  final Set<GameCharacter> _visibleEnemies   = {};
  static const double _cullDistance = 3000.0;

  int _chunksGenerated = 0;
  int _chunksReused    = 0;
  int _platformsCulled = 0;

  final math.Random _random = math.Random();

  InfiniteWorldSystem({required this.game});

  // ── initialization ────────────────────────────────────────────────────────

  void initialize() {
    print('🌍 Initializing Infinite World System...');

    // ONE infinite ground for the entire world — never recycled.
    _ground = TiledGroundComponent(groundY: groundCentreY);
    _ground!.priority = 10;
    game.world.add(_ground!);
    game.platforms.add(_ground!);

    // Pre-fill chunk pool.
    for (int i = 0; i < activeChunks * 2; i++) {
      _chunkPool.add(_createEmptyChunk());
    }

    // Generate initial chunks (floating platforms only).
    for (int i = -2; i <= 2; i++) {
      _generateChunk(i);
    }

    // First wave near spawn after 3 s.
    final firstWave = WaveZone(
      chunkIndex: 0,
      spawnX: 1000,
      waveNumber: 1,
      difficulty: 1.0,
      enemyCount: 2,
    );
    _activeWaveZones[0] = firstWave;
    Future.delayed(const Duration(seconds: 3), () {
      if (!game.isGameOver) _triggerWave(firstWave);
    });

    print('✅ Infinite World ready');
    print('   groundSurfaceY = $groundSurfaceY');
    print('   chunks in pool : ${_chunkPool.length}');
  }

  // ── update ────────────────────────────────────────────────────────────────

  void update(double dt, Vector2 playerPosition) {
    final chunkIndex = (playerPosition.x / chunkWidth).floor();
    _distanceTraveled = playerPosition.x;

    if (chunkIndex != _currentChunkIndex) {
      _onChunkTransition(chunkIndex);
      _currentChunkIndex = chunkIndex;
    }

    _updateCulling(playerPosition);
    _updateWaveZones(dt, playerPosition);
  }

  // ── chunk generation ──────────────────────────────────────────────────────

  void _generateChunk(int chunkIndex) {
    if (_activeChunks.containsKey(chunkIndex)) return;

    final chunk = _chunkPool.isNotEmpty
        ? _reuseChunk(chunkIndex)
        : _createNewChunk(chunkIndex);

    _activeChunks[chunkIndex] = chunk;
    _generateFloatingPlatforms(chunk);   // ← ground is no longer here
    _checkWaveSpawn(chunk);

    print('📦 Chunk $chunkIndex (${chunk.platforms.length} floating platforms)');
  }

  /// Only floating platforms — ground is handled by TiledGroundComponent.
  void _generateFloatingPlatforms(WorldChunk chunk) {
    final factory = PlatformFactory();
    final count   = 3 + _random.nextInt(4);

    for (int i = 0; i < count; i++) {
      final x     = chunk.startX + 200 + _random.nextDouble() * (chunk.width - 400);
      final y     = groundSurfaceY - 150 - _random.nextDouble() * 400; // above ground
      final width = 120.0 + _random.nextDouble() * 150;

      final platform = factory.createPlatform(
        position: Vector2(x, y),
        size: Vector2(width, 30),
        platformType: _random.nextBool() ? 'brick' : 'stone',
        priority: 10,
      );

      chunk.platforms.add(platform);
      game.world.add(platform);
      game.platforms.add(platform);
    }
  }

  WorldChunk _reuseChunk(int chunkIndex) {
    final chunk = _chunkPool.removeLast();
    chunk.reset(index: chunkIndex, startX: chunkIndex * chunkWidth);
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

  // ── chunk transitions ─────────────────────────────────────────────────────

  void _onChunkTransition(int newIndex) {
    print('🏃 Player → chunk $newIndex');
    for (int i = newIndex - 2; i <= newIndex + 2; i++) {
      _generateChunk(i);
    }
    _unloadDistantChunks(newIndex);
  }

  void _unloadDistantChunks(int currentIndex) {
    final toRemove = <int>[];
    _activeChunks.forEach((index, _) {
      if ((index - currentIndex).abs() > 3) toRemove.add(index);
    });
    for (final i in toRemove) {
      _recycleChunk(_activeChunks.remove(i)!);
    }
  }

  void _recycleChunk(WorldChunk chunk) {
    // Only floating platforms are in chunk.platforms — ground is safe.
    for (final p in chunk.platforms) {
      p.removeFromParent();
      game.platforms.remove(p);
      _visiblePlatforms.remove(p);
    }
    chunk.platforms.clear();
    chunk.waveSpawned = false;
    _chunkPool.add(chunk);
    print('♻️  Recycled chunk ${chunk.index}');
  }

  // ── culling ───────────────────────────────────────────────────────────────

  void _updateCulling(Vector2 cameraPos) {
    _cullPlatforms(cameraPos);
    _cullEnemies(cameraPos);
  }

  void _cullPlatforms(Vector2 cameraPos) {
    int culled = 0;
    for (final platform in game.platforms) {
      // Never cull the infinite ground.
      if (platform is TiledGroundComponent) continue;

      final dist    = (platform.position - cameraPos).length;
      final visible = dist < _cullDistance;

      if (visible && !_visiblePlatforms.contains(platform)) {
        platform.priority = 10;
        _visiblePlatforms.add(platform);
      } else if (!visible && _visiblePlatforms.contains(platform)) {
        platform.priority = -1000;
        _visiblePlatforms.remove(platform);
        culled++;
      }
    }
    _platformsCulled += culled;
  }

  void _cullEnemies(Vector2 cameraPos) {
    for (final enemy in game.enemies) {
      final dist    = (enemy.position - cameraPos).length;
      final visible = dist < _cullDistance || dist < 2500;
      if (visible)  _visibleEnemies.add(enemy);
      else if (dist > 4000) _visibleEnemies.remove(enemy);
    }
  }

  // ── wave spawning ─────────────────────────────────────────────────────────

  void _checkWaveSpawn(WorldChunk chunk) {
    if (chunk.index > 0 && chunk.index % 2 == 0) {
      _activeWaveZones[chunk.index] = WaveZone(
        chunkIndex: chunk.index,
        spawnX: chunk.centerX,
        waveNumber: _totalWavesSpawned + 1,
        difficulty: 1.0 + chunk.index * 0.1,
        enemyCount: (2 + (chunk.index / 3).floor()).clamp(2, 8),
      );
    }
  }

  void _updateWaveZones(double dt, Vector2 playerPos) {
    final toTrigger = <int>[];
    _activeWaveZones.forEach((idx, zone) {
      if (!zone.triggered &&
          (playerPos.x - zone.spawnX).abs() < chunkWidth * 0.5) {
        toTrigger.add(idx);
      }
    });
    for (final idx in toTrigger) {
      _triggerWave(_activeWaveZones[idx]!);
    }
  }

  void _triggerWave(WaveZone zone) {
    zone.triggered = true;
    _totalWavesSpawned++;
    print('⚔️  Wave ${zone.waveNumber} triggered at x=${zone.spawnX.toInt()}');
    _spawnWaveEnemies(zone);
    game.eventBus.emit(ShowNotificationEvent(
      message: '⚠️ WAVE ${zone.waveNumber}!',
      duration: Duration(minutes: 2),
    ));
  }

  void _spawnWaveEnemies(WaveZone zone) {
    final types   = ['knight', 'thief', 'wizard', 'trader'];
    final tactics = [AggressiveTactic(), BalancedTactic(), DefensiveTactic(), TacticalTactic()];

    for (int i = 0; i < zone.enemyCount; i++) {
      final side   = i % 2 == 0 ? 1.0 : -1.0;
      final offset = 300.0 + _random.nextDouble() * 400;
      final spawnX = zone.spawnX + side * offset;

      final type   = types[_random.nextInt(types.length)];
      final tactic = tactics[_random.nextInt(tactics.length)];
      final id     = 'wave${zone.waveNumber}_${type}_$i';

      // Use the shared spawnY helper — no magic numbers.
      final pos = Vector2(spawnX, spawnY(100));

      final enemy = _buildEnemy(type, pos, tactic, id, zone.difficulty);
      if (enemy == null) continue;

      enemy.priority = 90;
      game.world.add(enemy);
      game.enemies.add(enemy);
      game.registerCharacter(enemy);
    }
  }

  GameCharacter? _buildEnemy(
      String type, Vector2 pos, BotTactic tactic, String id, double difficulty) {
    GameCharacter? e;
    switch (type) {
      case 'knight': e = Knight(position: pos, playerType: PlayerType.bot, botTactic: tactic, customId: id); break;
      case 'thief':  e = Thief( position: pos, playerType: PlayerType.bot, botTactic: tactic, customId: id); break;
      case 'wizard': e = Wizard(position: pos, playerType: PlayerType.bot, botTactic: tactic, customId: id); break;
      case 'trader': e = Trader(position: pos, playerType: PlayerType.bot, botTactic: tactic, customId: id); break;
    }
    if (e != null) {
      e.characterState.health     *= difficulty;
      e.stats.attackDamage        *= difficulty;
    }
    return e;
  }

  // ── stats ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> getStats() => {
    'distanceTraveled': _distanceTraveled.toInt(),
    'currentChunk':     _currentChunkIndex,
    'activeChunks':     _activeChunks.length,
    'chunksGenerated':  _chunksGenerated,
    'chunksReused':     _chunksReused,
    'platformsCulled':  _platformsCulled,
    'totalWaves':       _totalWavesSpawned,
  };

  void printStats() {
    final s = getStats();
    print('🌍 World: dist=${s['distanceTraveled']}  chunk=${s['currentChunk']}  '
        'waves=${s['totalWaves']}  culled=${s['platformsCulled']}');
  }

  // ── disposal ──────────────────────────────────────────────────────────────

  void dispose() {
    _ground?.removeFromParent();
    if (_ground != null) game.platforms.remove(_ground);
    _activeChunks.clear();
    _chunkPool.clear();
    _activeWaveZones.clear();
    _visiblePlatforms.clear();
    _visibleEnemies.clear();
    print('🗑️  InfiniteWorldSystem disposed');
  }
}