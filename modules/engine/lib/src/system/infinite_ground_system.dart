import 'dart:math' as math;
import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Complete infinite ground system with enemy spawning
/// Provides endless horizontal ground for simple combat-focused gameplay
class InfiniteGroundSystem {
  final ActionGame game;

  // Configuration
  static const double groundWidth = 20000.0;
  static const double groundHeight = 80.0;
  static const double groundY = 1000.0;
  static const double wrapThreshold = 15000.0;

  // Enemy spawning
  static const int maxEnemies = 6;
  static const double spawnDistance = 800.0;
  static const double minSpawnDistance = 600.0;

  // Ground platform
  TiledPlatform? _groundPlatform;

  // Tracking
  double _totalDistanceTraveled = 0;
  int _wrapCount = 0;
  int _enemiesSpawned = 0;
  double _spawnTimer = 0;
  final math.Random _random = math.Random();

  InfiniteGroundSystem({required this.game});

  /// Initialize the infinite ground
  void initialize() {
    print('🌍 Initializing Infinite Ground System...');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Create single massive ground platform
    _groundPlatform = TiledPlatform(
      position: Vector2(groundWidth / 2, groundY),
      size: Vector2(groundWidth, groundHeight),
      platformType: 'ground',
    );
    _groundPlatform!.priority = 10;

    game.world.add(_groundPlatform!);
    game.platforms.add(_groundPlatform!);

    print('✅ Ground created: ${groundWidth.toInt()}px wide');
    print('   Position: (${(groundWidth/2).toInt()}, ${groundY.toInt()})');
    print('   Height: ${groundHeight.toInt()}px');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  /// Update system
  void update(double dt, Vector2 playerPosition) {
    // Track distance
    _totalDistanceTraveled += playerPosition.x.abs() * dt * 0.1;

    // Handle wrapping for infinite effect
    _handleWrapping(playerPosition);

    // Dynamic enemy spawning
    _updateEnemySpawning(dt, playerPosition);
  }

  /// Handle player position wrapping
  void _handleWrapping(Vector2 playerPosition) {
    if (playerPosition.x > wrapThreshold) {
      _wrapPlayer(-wrapThreshold * 1.8);
    } else if (playerPosition.x < -wrapThreshold) {
      _wrapPlayer(wrapThreshold * 1.8);
    }
  }

  /// Wrap player and all enemies to new position
  void _wrapPlayer(double offset) {
    final oldX = game.character.position.x;

    // Wrap player
    game.character.position.x += offset;

    // Wrap all enemies to maintain relative positions
    for (final enemy in game.enemies) {
      enemy.position.x += offset;
    }

    // Wrap projectiles
    for (final projectile in game.projectiles) {
      projectile.position.x += offset;
    }

    _wrapCount++;

    print('🔄 World wrapped (${_wrapCount}x)');
    print('   Player: ${oldX.toInt()} → ${game.character.position.x.toInt()}');
  }

  /// Dynamic enemy spawning system
  void _updateEnemySpawning(double dt, Vector2 playerPosition) {
    _spawnTimer += dt;

    // Spawn check every 3 seconds
    if (_spawnTimer < 3.0) return;
    _spawnTimer = 0;

    // Count alive enemies
    final aliveEnemies = game.enemies.where((e) =>
    e.characterState.health > 0 && e.isMounted
    ).length;

    if (aliveEnemies >= maxEnemies) return;

    // Spawn enemy away from player
    spawnRandomEnemy(playerPosition);
  }

  /// Spawn enemy at strategic position
  void spawnRandomEnemy(Vector2 playerPosition) {
    final enemyTypes = ['knight', 'thief', 'wizard', 'trader'];
    final tactics = [
      AggressiveTactic(),
      BalancedTactic(),
      DefensiveTactic(),
      TacticalTactic(),
    ];

    final randomType = enemyTypes[_random.nextInt(enemyTypes.length)];
    final randomTactic = tactics[_random.nextInt(tactics.length)];

    // Spawn position: ahead or behind player
    final direction = _random.nextBool() ? 1 : -1;
    final distance = minSpawnDistance + _random.nextDouble() * (spawnDistance - minSpawnDistance);
    final spawnX = playerPosition.x + (direction * distance);

    final spawnPos = getSpawnPosition(x: spawnX);

    // Create enemy
    GameCharacter enemy;
    switch (randomType) {
      case 'knight':
        enemy = Knight(
          position: spawnPos,
          playerType: PlayerType.bot,
          botTactic: randomTactic,
          customId: 'ground_${randomType}_${_enemiesSpawned}',
        );
        break;
      case 'thief':
        enemy = Thief(
          position: spawnPos,
          playerType: PlayerType.bot,
          botTactic: randomTactic,
          customId: 'ground_${randomType}_${_enemiesSpawned}',
        );
        break;
      case 'wizard':
        enemy = Wizard(
          position: spawnPos,
          playerType: PlayerType.bot,
          botTactic: randomTactic,
          customId: 'ground_${randomType}_${_enemiesSpawned}',
        );
        break;
      case 'trader':
        enemy = Trader(
          position: spawnPos,
          playerType: PlayerType.bot,
          botTactic: randomTactic,
          customId: 'ground_${randomType}_${_enemiesSpawned}',
        );
        break;
      default:
        return;
    }

    enemy.priority = 90;
    game.world.add(enemy);
    game.enemies.add(enemy);

    // Register in game's character registry (if available)
    if (game.characterRegistry != null) {
      game.characterRegistry[enemy.uniqueId] = enemy;
    }

    _enemiesSpawned++;

    print('✨ Spawned: $randomType (${randomTactic.name}) at ${spawnX.toInt()}');
  }

  /// Get spawn position on ground
  Vector2 getSpawnPosition({double x = 0}) {
    final spawnY = groundY - groundHeight / 2 - 120;
    return Vector2(x, spawnY);
  }

  /// Get random spawn position
  Vector2 getRandomEnemySpawnPosition() {
    final playerX = game.character.position.x;
    final direction = game.character.facingRight ? 1 : -1;
    final distance = minSpawnDistance + _random.nextDouble() * spawnDistance;
    final spawnX = playerX + (direction * distance);

    return getSpawnPosition(x: spawnX);
  }

  /// Check if position is on ground
  bool isOnGround(Vector2 position, {double tolerance = 50}) {
    final groundTop = groundY - groundHeight / 2;
    return (position.y - groundTop).abs() < tolerance;
  }

  /// Spawn initial wave of enemies
  void spawnInitialEnemies({int count = 3}) {
    print('\n🎮 Spawning initial enemies...');

    for (int i = 0; i < count; i++) {
      final playerX = game.character.position.x;
      final offset = (i + 1) * 400 * (i % 2 == 0 ? 1 : -1);

      final spawnPos = getSpawnPosition(x: playerX + offset);

      final enemyTypes = ['knight', 'thief', 'wizard', 'trader'];
      final tactics = [AggressiveTactic(), BalancedTactic(), DefensiveTactic()];

      GameCharacter enemy;
      final type = enemyTypes[i % enemyTypes.length];

      switch (type) {
        case 'knight':
          enemy = Knight(
            position: spawnPos,
            playerType: PlayerType.bot,
            botTactic: tactics[i % tactics.length],
            customId: 'initial_$type\_$i',
          );
          break;
        case 'thief':
          enemy = Thief(
            position: spawnPos,
            playerType: PlayerType.bot,
            botTactic: tactics[i % tactics.length],
            customId: 'initial_$type\_$i',
          );
          break;
        case 'wizard':
          enemy = Wizard(
            position: spawnPos,
            playerType: PlayerType.bot,
            botTactic: tactics[i % tactics.length],
            customId: 'initial_$type\_$i',
          );
          break;
        case 'trader':
          enemy = Trader(
            position: spawnPos,
            playerType: PlayerType.bot,
            botTactic: tactics[i % tactics.length],
            customId: 'initial_$type\_$i',
          );
          break;
        default:
          continue;
      }

      enemy.priority = 90;
      game.world.add(enemy);
      game.enemies.add(enemy);

      print('  ✅ $type at ${spawnPos.x.toInt()}');
    }

    print('');
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'totalDistance': _totalDistanceTraveled.toInt(),
      'wrapCount': _wrapCount,
      'enemiesSpawned': _enemiesSpawned,
      'activeEnemies': game.enemies.where((e) => e.characterState.health > 0).length,
      'playerX': game.character.position.x.toInt(),
    };
  }

  void printStats() {
    final stats = getStats();
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🌍 INFINITE GROUND STATISTICS');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Total Distance: ${stats['totalDistance']}m');
    print('Wrap Count: ${stats['wrapCount']}');
    print('Enemies Spawned: ${stats['enemiesSpawned']}');
    print('Active Enemies: ${stats['activeEnemies']}');
    print('Player X: ${stats['playerX']}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  /// Dispose
  void dispose() {
    _groundPlatform?.removeFromParent();
    game.platforms.remove(_groundPlatform);
    print('🗑️  InfiniteGroundSystem disposed');
  }
}