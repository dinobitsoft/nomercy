// modules/engine/lib/src/system/infinite_world_3d.dart

import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

import '../bot/bot_personality_3d.dart';
import '../components/obstacle/obstacle_3d.dart';
import '../components/obstacle/obstacle_builder_3d.dart';
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

    // ── 1. Simple ground-level box obstacles (always present) ────────────
    _addGroundObstacles(chunk, zStart);

    // ── 2. Complex structure (one per chunk, type rotates with distance) ──
    _addComplexStructure(chunk, zStart);

    // ── 3. Elevated floating platforms (1-2 per chunk) ───────────────────
    final elevatedCount = 1 + _rng.nextInt(2);
    for (int i = 0; i < elevatedCount; i++) {
      final z     = zStart + 600 + _rng.nextDouble() * (chunkDepth - 1200);
      final x     = (_rng.nextDouble() - 0.5) * chunkWidth * 0.55;
      final y     = GameConfig3D.infiniteGroundY + 220 + _rng.nextDouble() * 180;
      final sizeX = 180 + _rng.nextDouble() * 140;

      _spawnPlatform(chunk,
        worldPos: WorldPos(x, y, z),
        sizeX:    sizeX,
        sizeY:    GameConfig3D.platformHeight,
        sizeZ:    GameConfig3D.platformDepthZ,
        type:     _pickType(),
      );
    }
  }

  /// Ground-level single-box obstacles — simple barriers to jump over or
  /// navigate around. Always leaves at least one X-lane open.
  void _addGroundObstacles(WorldChunk3D chunk, double zStart) {
    final base  = 2 + (chunk.index.abs() ~/ 3).clamp(0, 3);
    final count = base + _rng.nextInt(2);
    final slotZ = (chunkDepth - 600) / count;

    for (int i = 0; i < count; i++) {
      final z = zStart + 300 + i * slotZ + _rng.nextDouble() * slotZ * 0.5;

      // Three X lanes — block 1 or 2, always leave at least one open.
      final lanes        = [-chunkWidth * 0.28, 0.0, chunkWidth * 0.28];
      final blockedCount = 1 + _rng.nextInt(2);
      final shuffled     = List.of(lanes)..shuffle(_rng);

      for (int b = 0; b < blockedCount; b++) {
        final boxH = GameConfig3D.platformHeight * (0.8 + _rng.nextDouble() * 0.7);
        final topY = GameConfig3D.groundSurfaceY + boxH;
        _spawnObstacle(chunk,
          worldPos: WorldPos(shuffled[b], topY, z),
          sizeX:    110 + _rng.nextDouble() * 110,
          sizeY:    boxH,
          sizeZ:    GameConfig3D.platformDepthZ * (0.6 + _rng.nextDouble() * 0.5),
          type:     _pickObstacleType(),
        );
      }
    }
  }

  /// Spawns one of five complex multi-block structures per chunk.
  /// The structure type is chosen deterministically from the chunk index so
  /// the world feels varied without being purely random.
  void _addComplexStructure(WorldChunk3D chunk, double zStart) {
    if (chunk.index <= 0) return; // skip the very first chunk (player spawn area)

    // Place structure at the mid-point of the chunk with a small random offset.
    final z = zStart + chunkDepth * 0.45 + (_rng.nextDouble() - 0.5) * 200;
    final x = (_rng.nextDouble() - 0.5) * chunkWidth * 0.45;
    final origin = WorldPos(x, GameConfig3D.groundSurfaceY, z);

    // Rotate through structure types based on chunk index.
    final structureType = chunk.index.abs() % 5;

    List<Obstacle3D> blocks;
    switch (structureType) {
      case 0:
        // Stairway — ascending steps, easy to climb.
        blocks = ObstacleBuilder3D.stairway(
          origin:     origin,
          steps:      4 + _rng.nextInt(2),
          stepWidth:  190 + _rng.nextDouble() * 60,
          stepHeight: 55 + _rng.nextDouble() * 15,
          stepDepth:  85 + _rng.nextDouble() * 20,
          type:       _pickObstacleType(),
        );

      case 1:
        // Elevated platform — two columns + wide slab above.
        blocks = ObstacleBuilder3D.elevatedPlatform(
          origin:          origin,
          platformHeight:  200 + _rng.nextDouble() * 80,
          platformWidth:   500 + _rng.nextDouble() * 160,
          platformDepth:   180 + _rng.nextDouble() * 60,
          slabThickness:   60,
          columnWidth:     90,
          type:            _pickObstacleType(),
        );

      case 2:
        // Archway — two pillars + lintel, run through the gap.
        blocks = ObstacleBuilder3D.archway(
          origin:       origin,
          openingWidth: 300 + _rng.nextDouble() * 80,
          pillarHeight: 240 + _rng.nextDouble() * 80,
          pillarWidth:  80,
          pillarDepth:  80,
          lintelThick:  60,
          type:         _pickObstacleType(),
        );

      case 3:
        // Zigzag ramp — zig-zag path upward, forces lateral movement.
        blocks = ObstacleBuilder3D.zigzagRamp(
          origin:      origin,
          levels:      4 + _rng.nextInt(2),
          levelHeight: 55 + _rng.nextDouble() * 15,
          blockWidth:  260 + _rng.nextDouble() * 60,
          blockDepth:  130 + _rng.nextDouble() * 30,
          type:        _pickObstacleType(),
        );

      default:
        // Pyramid — multi-layer square pyramid.
        blocks = ObstacleBuilder3D.pyramid(
          origin:      origin,
          layers:      3 + _rng.nextInt(2),
          baseWidth:   440 + _rng.nextDouble() * 100,
          layerHeight: 55 + _rng.nextDouble() * 15,
          stepInset:   55,
          type:        _pickObstacleType(),
        );
    }

    for (final obs in blocks) {
      game.world.add(obs);
      game.obstacles3D.add(obs);
      chunk.obstacles.add(obs);
    }
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

  /// Spawn a solid [Obstacle3D] — registered in both [game.obstacles3D] and
  /// the chunk so it is recycled with the chunk lifecycle.
  void _spawnObstacle(WorldChunk3D chunk, {
    required WorldPos worldPos,
    required double sizeX, required double sizeY, required double sizeZ,
    required String type,
  }) {
    final o = Obstacle3D(
      worldPos:     worldPos,
      sizeX:        sizeX,
      sizeY:        sizeY,
      sizeZ:        sizeZ,
      obstacleType: type,
      priority:     IsoProjection.depthPriority(worldPos) + 10,
    );
    game.world.add(o);
    game.obstacles3D.add(o);
    chunk.obstacles.add(o);
  }

  /// Distribute personalities so early waves are pure aggressors;
  /// later waves progressively introduce the other three personalities.
  BotPersonality3D _pickPersonality(int wave, int index, int total) {
    if (wave <= 2) return BotPersonality3D.aggressor;
    if (wave <= 4) {
      // One flanker as the "pack leader", rest aggressors.
      return index == 0 ? BotPersonality3D.flanker : BotPersonality3D.aggressor;
    }
    if (wave <= 7) {
      const pool = [
        BotPersonality3D.aggressor,
        BotPersonality3D.aggressor,
        BotPersonality3D.flanker,
        BotPersonality3D.ranged,
      ];
      return pool[_rng.nextInt(pool.length)];
    }
    // Wave 8+: all four personalities in play.
    return BotPersonality3D.values[_rng.nextInt(BotPersonality3D.values.length)];
  }

  String _pickType() {
    const types = ['brick', 'stone', 'ice', 'brick', 'stone'];
    return types[_rng.nextInt(types.length)];
  }

  /// Obstacle types — heavier/denser look for ground boxes.
  String _pickObstacleType() {
    const types = ['brick', 'brick', 'stone', 'stone', 'ground'];
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
    const charTypes = ['knight', 'thief', 'wizard', 'trader'];

    for (int i = 0; i < count; i++) {
      final type        = charTypes[_rng.nextInt(charTypes.length)];
      final x           = (_rng.nextDouble() - 0.5) * chunkWidth * 0.6;
      final spawn       = WorldPos(x, 0, z + i * 80.0);
      final personality = _pickPersonality(wave, i, count);

      game.spawnEnemy3D(
        characterClass: type,
        spawnPos:       spawn,
        difficultyMult: difficulty,
        personality:    personality,
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
    for (final obs in game.obstacles3D) {
      final dz = (obs.worldPos.z - playerPos.z).abs();
      final dx = (obs.worldPos.x - playerPos.x).abs();
      final visible = dz < cullZ && dx < chunkWidth * 1.5;
      obs.priority = visible
          ? IsoProjection.depthPriority(obs.worldPos) + 10
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

    for (final o in chunk.obstacles) {
      if (o.isMounted) o.removeFromParent();
      game.obstacles3D.remove(o);
    }
    chunk.obstacles.clear();

    _pool.add(chunk);
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

class WorldChunk3D {
  final int id;
  int index;
  final List<GamePlatform3D> platforms = [];
  final List<Obstacle3D>     obstacles = [];

  WorldChunk3D({required this.id, required this.index});

  void reset(int newIndex) {
    index = newIndex;
    platforms.clear();
    obstacles.clear();
  }
}