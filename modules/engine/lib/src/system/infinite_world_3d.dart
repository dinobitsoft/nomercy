// modules/engine/lib/src/system/infinite_world_3d.dart

import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

import '../components/platform/game_platform_3d.dart';

/// Generates the infinite 3D world in Z-direction chunks.
///
/// The player runs forward (+Z). Each chunk is [chunkDepth] units deep
/// and [chunkWidth] units wide (X). Floating platforms are generated with
/// safe jump gaps and varied heights (Y).
///
/// Ground is handled by [InfiniteGround3D] — never added to chunk.platforms.
class InfiniteWorldSystem3D {
  final ActionGame3D game;

  // ── chunk geometry ─────────────────────────────────────────────────────────
  static const double chunkDepth  = GameConfig3D.chunkDepthZ;
  static const double chunkWidth  = GameConfig3D.chunkWidthX;
  static const int    activeRange = 2;   // chunks ahead and behind

  // ── ground ─────────────────────────────────────────────────────────────────
  static double spawnY(double charHeight) =>
      GameConfig3D.infiniteGroundY + charHeight;

  // ── state ──────────────────────────────────────────────────────────────────
  final Map<int, WorldChunk3D> _chunks   = {};
  final List<WorldChunk3D>     _pool     = [];
  int _currentChunkIndex = 0;
  int _nextId            = 0;
  int _totalWaves        = 0;

  final math.Random _rng = math.Random();

  InfiniteWorldSystem3D({required this.game});

  // ── init ───────────────────────────────────────────────────────────────────

  void initialize() {
    // Infinite visual ground (no collision needed — collision is at Y=0).
    final ground = InfiniteGround3D();
    game.world.add(ground);

    // Spawn initial chunks.
    for (int i = -1; i <= activeRange + 1; i++) _generateChunk(i);

    print('✅ InfiniteWorldSystem3D ready');
  }

  // ── per-frame update ───────────────────────────────────────────────────────

  void update(double dt, WorldPos playerPos) {
    final chunkIdx = (playerPos.z / chunkDepth).floor();
    if (chunkIdx != _currentChunkIndex) {
      _currentChunkIndex = chunkIdx;
      _onChunkTransition(chunkIdx);
    }
    _updateCulling(playerPos);
  }

  // ── chunk lifecycle ────────────────────────────────────────────────────────

  void _onChunkTransition(int idx) {
    for (int i = idx - 1; i <= idx + activeRange + 1; i++) _generateChunk(i);
    _unloadDistant(idx);
  }

  void _generateChunk(int idx) {
    if (_chunks.containsKey(idx)) return;

    final chunk = _pool.isNotEmpty
        ? (_pool.removeLast()..reset(idx))
        : WorldChunk3D(id: _nextId++, index: idx);

    _chunks[idx] = chunk;
    _buildPlatforms(chunk);

    if (idx > 0 && idx % 3 == 0) _scheduleWave(chunk);
  }

  void _buildPlatforms(WorldChunk3D chunk) {
    final zStart = chunk.index * chunkDepth;
    final zEnd   = zStart + chunkDepth;

    // Number of platforms scales with distance (more challenge further out).
    final count = 3 + math.min(_rng.nextInt(4) + (chunk.index.abs() ~/ 5), 7);

    // Guarantee at least one "safe path" platform per column of 600 Z units.
    _addSafePath(chunk, zStart, zEnd);

    // Additional challenge platforms.
    for (int i = 0; i < count; i++) {
      final z       = zStart + 200 + _rng.nextDouble() * (chunkDepth - 400);
      final x       = (_rng.nextDouble() - 0.5) * chunkWidth * 0.8;
      final y       = GameConfig3D.infiniteGroundY +
          80 + _rng.nextDouble() * 380;          // Y above ground
      final sizeX   = 120 + _rng.nextDouble() * 200;
      final sizeZ   = GameConfig3D.platformDepthZ;
      final type    = _pickType();

      _spawnPlatform(chunk,
        worldPos: WorldPos(x, y, z),
        sizeX: sizeX, sizeY: GameConfig3D.platformHeight, sizeZ: sizeZ,
        type: type,
      );
    }
  }

  /// One guaranteed accessible platform near the centre X, reachable from
  /// the ground or previous safe platform.
  void _addSafePath(WorldChunk3D chunk, double zStart, double zEnd) {
    final z    = zStart + chunkDepth * 0.5;
    final y    = GameConfig3D.infiniteGroundY + 100 + _rng.nextDouble() * 180;
    const sizeX = 260.0;

    _spawnPlatform(chunk,
      worldPos: WorldPos(0, y, z),
      sizeX: sizeX,
      sizeY: GameConfig3D.platformHeight,
      sizeZ: GameConfig3D.platformDepthZ,
      type: 'ground',
    );
  }

  void _spawnPlatform(WorldChunk3D chunk, {
    required WorldPos worldPos,
    required double sizeX, required double sizeY, required double sizeZ,
    required String type,
  }) {
    final p = GamePlatform3D(
      worldPos:     worldPos,
      sizeX:        sizeX,
      sizeY:        sizeY,
      sizeZ:        sizeZ,
      platformType: type,
      priority:     IsoProjection.depthPriority(worldPos),
    );
    game.world.add(p);
    game.platforms3D.add(p);
    chunk.platforms.add(p);
  }

  String _pickType() {
    const types = ['brick', 'stone', 'ice', 'brick', 'ground', 'stone'];
    return types[_rng.nextInt(types.length)];
  }

  // ── wave spawning ──────────────────────────────────────────────────────────

  void _scheduleWave(WorldChunk3D chunk) {
    _totalWaves++;
    final waveNum    = _totalWaves;
    final difficulty = 1.0 + chunk.index * 0.08;
    final count      = (2 + (chunk.index ~/ 4)).clamp(2, 7);
    final spawnZ     = chunk.index * chunkDepth + chunkDepth * 0.4;

    // Delay until player arrives.
    Future.delayed(Duration.zero, () {
      if (!game.isGameOver) {
        _spawnEnemies(spawnZ, waveNum, difficulty, count);
      }
    });
  }

  void _spawnEnemies(double z, int wave, double difficulty, int count) {
    const types = ['knight', 'thief', 'wizard', 'trader'];

    for (int i = 0; i < count; i++) {
      final type  = types[_rng.nextInt(types.length)];
      final x     = (_rng.nextDouble() - 0.5) * chunkWidth * 0.6;
      final spawn = WorldPos(x, 0, z + i * 80.0);

      game.spawnEnemy3D(
        characterClass:    type,
        spawnPos:          spawn,
        difficultyMult:    difficulty,
      );
    }

    game.eventBus.emit(ShowNotificationEvent(
      message: '⚠️ WAVE $wave!',
      duration: const Duration(seconds: 2),
    ));
  }

  // ── culling ────────────────────────────────────────────────────────────────

  void _updateCulling(WorldPos playerPos) {
    const cullZ = 4000.0;
    for (final platform in game.platforms3D) {
      final dz = (platform.worldPos.z - playerPos.z).abs();
      final dx = (platform.worldPos.x - playerPos.x).abs();
      final visible = dz < cullZ && dx < chunkWidth * 1.5;
      platform.priority = visible
          ? IsoProjection.depthPriority(platform.worldPos)
          : -9999;
    }
  }

  // ── unload ─────────────────────────────────────────────────────────────────

  void _unloadDistant(int currentIdx) {
    final toRemove = <int>[];
    _chunks.forEach((idx, _) {
      if ((idx - currentIdx).abs() > activeRange + 3) toRemove.add(idx);
    });
    for (final idx in toRemove) {
      _recycleChunk(_chunks.remove(idx)!);
    }
  }

  void _recycleChunk(WorldChunk3D chunk) {
    for (final p in chunk.platforms) {
      if (p.isMounted) p.removeFromParent();
      game.platforms3D.remove(p);
    }
    chunk.platforms.clear();
    _pool.add(chunk);
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

class WorldChunk3D {
  final int id;
  int index;
  final List<GamePlatform3D> platforms = [];

  WorldChunk3D({required this.id, required this.index});

  void reset(int newIndex) {
    index = newIndex;
    platforms.clear();
  }
}