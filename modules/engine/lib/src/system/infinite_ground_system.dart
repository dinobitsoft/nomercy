import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

class InfiniteGroundSystem {
  final ActionGame game;

  // ── ground config ──────────────────────────────────────────────────────────
  static const double groundY = 950.0;

  // Platform top surface Y in world space
  static double get platformTopY => groundY - TiledGroundComponent.tileSize / 2;

  // ── enemy config ───────────────────────────────────────────────────────────
  static const int    maxEnemies       = 6;
  static const double spawnDistance    = 800.0;
  static const double minSpawnDistance = 400.0;

  // ── state ──────────────────────────────────────────────────────────────────
  TiledGroundComponent? _ground;
  double _spawnTimer   = 0;
  int    _enemiesSpawned = 0;
  final  math.Random _random = math.Random();

  InfiniteGroundSystem({required this.game});

  // ── initialization ─────────────────────────────────────────────────────────

  void initialize() {
    print('🌍 InfiniteGroundSystem initializing...');
    print('   groundY=$groundY  platformTop=$platformTopY');

    _ground          = TiledGroundComponent(groundY: groundY);
    _ground!.priority = 10;

    game.world.add(_ground!);
    game.platforms.add(_ground!);

    print('✅ Infinite tiled ground ready');
  }

  /// Spawn Y so the character's feet land exactly on the ground surface.
  /// [characterHeight] defaults to 100 — adjust if your sprites differ.
  Vector2 getSpawnPosition({required double x, double characterHeight = 100}) {
    // FIX BUG 2: place character so bottom = platformTopY (exactly on surface)
    final centerY = platformTopY - characterHeight / 2;
    return Vector2(x, centerY);
  }

  // ── update ─────────────────────────────────────────────────────────────────

  void update(double dt, Vector2 playerPosition) {
    _updateEnemySpawning(dt, playerPosition);
  }

  // ── enemy spawning ─────────────────────────────────────────────────────────

  void spawnInitialEnemies({int count = 4}) {
    print('👾 Spawning $count initial enemies...');
    final playerX = game.character.position.x;

    final enemyTypes = ['knight', 'thief', 'wizard', 'trader'];
    final tactics    = [AggressiveTactic(), BalancedTactic(), DefensiveTactic()];

    for (int i = 0; i < count; i++) {
      final side   = (i % 2 == 0) ? 1 : -1;
      final offset = minSpawnDistance + _random.nextDouble() * 400;
      final spawnX = playerX + side * offset;
      final type   = enemyTypes[i % enemyTypes.length];

      final enemy = _buildEnemy(
        type,
        getSpawnPosition(x: spawnX),
        tactics[i % tactics.length],
        'initial_${type}_$i',
      );
      if (enemy == null) continue;

      enemy.priority = 90;
      game.world.add(enemy);
      game.enemies.add(enemy);
      game.registerCharacter(enemy);
      print('  ✅ $type at ${spawnX.toInt()}');
    }
  }

  void _updateEnemySpawning(double dt, Vector2 playerPosition) {
    _spawnTimer += dt;
    if (_spawnTimer < 3.0) return;
    _spawnTimer = 0;

    final alive = game.enemies
        .where((e) => e.characterState.health > 0 && e.isMounted)
        .length;
    if (alive >= maxEnemies) return;

    spawnRandomEnemy(playerPosition);
  }

  void spawnRandomEnemy(Vector2 playerPosition) {
    final types   = ['knight', 'thief', 'wizard', 'trader'];
    final tactics = [AggressiveTactic(), BalancedTactic(), DefensiveTactic(), TacticalTactic()];
    final type    = types[_random.nextInt(types.length)];
    final tactic  = tactics[_random.nextInt(tactics.length)];
    final side    = _random.nextBool() ? 1.0 : -1.0;
    final dist    = minSpawnDistance + _random.nextDouble() * (spawnDistance - minSpawnDistance);
    final spawnX  = playerPosition.x + side * dist;
    final id      = 'spawned_${type}_${_enemiesSpawned++}';

    final enemy = _buildEnemy(type, getSpawnPosition(x: spawnX), tactic, id);
    if (enemy == null) return;

    enemy.priority = 90;
    game.world.add(enemy);
    game.enemies.add(enemy);
    game.registerCharacter(enemy);
  }

  GameCharacter? _buildEnemy(String type, Vector2 pos, BotTactic tactic, String id) {
    switch (type) {
      case 'knight': return Knight(position: pos, playerType: PlayerType.bot, botTactic: tactic, customId: id);
      case 'thief':  return Thief( position: pos, playerType: PlayerType.bot, botTactic: tactic, customId: id);
      case 'wizard': return Wizard(position: pos, playerType: PlayerType.bot, botTactic: tactic, customId: id);
      case 'trader': return Trader(position: pos, playerType: PlayerType.bot, botTactic: tactic, customId: id);
      default: return null;
    }
  }

  // ── disposal ───────────────────────────────────────────────────────────────

  void dispose() {
    _ground?.removeFromParent();
    game.platforms.remove(_ground);
    _ground = null;
  }
}