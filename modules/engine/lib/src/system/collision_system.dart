import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

class CollisionSystem {
  final SpatialHashGrid<GameCharacter> _characterGrid =
  SpatialHashGrid(cellSize: 300.0);

  final SpatialHashGrid<Projectile> _projectileGrid =
  SpatialHashGrid(cellSize: 200.0);

  final SpatialHashGrid<GamePlatform> _platformGrid =
  SpatialHashGrid(cellSize: 400.0);

  /// Update all grids (call once per frame)
  void updateGrids({
    required List<GameCharacter> characters,
    required List<Projectile> projectiles,
    required List<GamePlatform> platforms,
  }) {
    // Clear grids
    _characterGrid.clear();
    _projectileGrid.clear();

    // Platforms are static, only update once
    if (_platformGrid.getStats()['totalObjects'] == 0) {
      for (final platform in platforms) {
        _platformGrid.insert(platform, platform.position, platform.size);
      }
    }

    // Update character grid
    for (final character in characters) {
      _characterGrid.insert(character, character.position, character.size);
    }

    // Update projectile grid
    for (final projectile in projectiles) {
      _projectileGrid.insert(projectile, projectile.position, projectile.size);
    }
  }

  /// Check character vs platform collisions (optimized)
  GamePlatform? checkPlatformCollision(GameCharacter character) {  // ✅ Changed return type
    final nearbyPlatforms = _platformGrid.getNearby(
      character.position,
      character.size,
    );

    for (final platform in nearbyPlatforms) {
      if (_checkAABB(
        character.position, character.size,
        platform.position, platform.size,
      )) {
        // Additional check: character falling onto platform from above
        if (character.velocity.y > 0 &&
            character.position.y < platform.position.y) {
          return platform;
        }
      }
    }

    return null;
  }

  /// Check character vs projectile collisions (optimized)
  void checkProjectileCollisions(List<GameCharacter> characters) {
    for (final character in characters) {
      // Only check projectiles in nearby cells
      final nearbyProjectiles = _projectileGrid.getNearby(
        character.position,
        character.size,
      );

      for (final projectile in nearbyProjectiles) {
        // Skip if same owner
        if (projectile.owner == character ||
            projectile.enemyOwner == character) {
          continue;
        }

        if (_checkAABB(
          character.position, character.size,
          projectile.position, projectile.size,
        )) {
          // Collision detected!
          _handleProjectileHit(character, projectile);
        }
      }
    }
  }


  /// AABB collision check
  bool _checkAABB(
      Vector2 pos1, Vector2 size1,
      Vector2 pos2, Vector2 size2,
      ) {
    final dx = (pos1.x - pos2.x).abs();
    final dy = (pos1.y - pos2.y).abs();
    return dx < (size1.x + size2.x) / 2 &&
        dy < (size1.y + size2.y) / 2;
  }

  void _handleProjectileHit(GameCharacter character, Projectile projectile) {
    character.takeDamage(projectile.damage);
    projectile.removeFromParent();

    // Calculate dynamic health percent based on max health
    final healthPercent = (character.characterState.health / GameConfig.characterBaseHealth) * 100;

    // Emit collision event
    EventBus().emit(CharacterDamagedEvent(
      characterId: character.stats.name,
      damage: projectile.damage,
      remainingHealth: character.characterState.health,
      healthPercent: healthPercent,
    ));
  }

  /// Print performance stats
  void printStats() {
    print('\n🔍 Collision System Stats:');
    print('  Character Grid: ${_characterGrid.getStats()}');
    print('  Projectile Grid: ${_projectileGrid.getStats()}');
    print('  Platform Grid: ${_platformGrid.getStats()}');
  }
}
