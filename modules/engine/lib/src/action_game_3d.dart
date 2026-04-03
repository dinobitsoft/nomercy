// modules/engine/lib/src/action_game_3d.dart

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'components/character/game_character_3d.dart';
import 'components/character/player_character_3d.dart';
import 'components/platform/game_platform_3d.dart';

/// Top-level game for the 3D (isometric) platformer.
///
/// Extends [ActionGame] so that all systems ([WaveSystem], [ItemSystem],
/// [UISystem]) that hold a reference to `ActionGame` work without casts.
///
/// Key differences from the 2D mode:
///   • [platforms3D] — 3D AABB boxes for physics.
///   • [PlayerCharacter3D] / [EnemyCharacter3D] hold a [WorldPos].
///   • [InfiniteWorldSystem3D] generates chunks along Z axis.
///   • [worldOriginOnScreen] maps world (0,0,0) to a screen point so
///     [IsoProjection] aligns with camera position.
class ActionGame3D extends ActionGame {

  // ── 3D-specific state ─────────────────────────────────────────────────────
  late PlayerCharacter3D character3D;
  final List<EnemyCharacter3D>        enemies3D         = [];
  final Map<String, GameCharacter3D>  characterRegistry3D = {};

  /// All 3D platforms — used for physics collision.
  final List<GamePlatform3D> platforms3D = [];

  InfiniteWorldSystem3D? _worldSystem3D;

  /// The screen position that maps to world (0,0,0).
  Vector2 worldOriginOnScreen = Vector2.zero();

  ActionGame3D({
    required super.selectedCharacterClass,
    required super.gameMode,
    super.mapName,
    super.procedural,
    super.mapConfig,
    super.enableMultiplayer,
  }) {
    // Tell ActionGame.onLoad to skip the 2D world setup.
    skipWorldSetup = true;
  }

  // ── onLoad ─────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    // Calls FlameGame.onLoad + initializeSystems(), then returns early
    // because skipWorldSetup is true — no 2D map/character creation.
    await super.onLoad();

    // Camera: anchor at 50% X, 65% Y — player slightly below centre.
    camera.viewfinder.zoom   = 1.0;
    camera.viewfinder.anchor = const Anchor(0.5, 0.65);

    worldOriginOnScreen = size / 2;

    // Background gradient.
    final bg = RectangleComponent(
      size: Vector2(100000, 60000),
      position: Vector2(-50000, -30000),
      paint: Paint()..shader = UIGradient.linear(
        const Offset(0, 0), const Offset(0, 2000),
        [const Color(0xFF0d1117), const Color(0xFF1a1a2e)],
      ).shader,
    )..priority = -9999;
    world.add(bg);

    // Spawn player.
    final spawnPos = WorldPos(0, 0, 0);
    final stats    = _statsFor(selectedCharacterClass);

    character3D = PlayerCharacter3D(
      characterClass: selectedCharacterClass,
      spawnPos:       spawnPos,
      stats:          stats,
    );
    character3D.priority = IsoProjection.depthPriority(spawnPos) + 200;
    world.add(character3D);
    characterRegistry3D['player_main'] = character3D;

    // Provide a 2D character reference for systems that read `game.character`.
    character = Knight(
      position: Vector2.zero(),
      playerType: PlayerType.human,
      customId: 'player_main',
    );

    // 3D world chunk system.
    _worldSystem3D = InfiniteWorldSystem3D(game: this);
    _worldSystem3D!.initialize();

    // On-screen joystick.
    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 24,
        paint: Paint()..color = Colors.white.withOpacity(0.55),
      ),
      background: CircleComponent(
        radius: 52,
        paint: Paint()..color = Colors.white.withOpacity(0.12),
      ),
      margin: const EdgeInsets.only(left: 44, bottom: 44),
    );
    camera.viewport.add(joystick);

    // HUD (3D variant — currently a no-op placeholder).
    uiSystem.buildHUD3D();

    // Music.
    audioSystem.playMusic('battle_theme');
  }

  // ── update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) return;

    _worldSystem3D?.update(dt, character3D.worldPos);
    _updateCamera3D(dt);
    _processCombat3D(dt);

    if (character3D.characterState.health <= 0 && !isGameOver) {
      isGameOver = true;
      eventBus.emit(GameOverEvent(
        reason: 'death',
        finalScore: 0,
        wavesCompleted: 0,
        enemiesKilled: enemiesDefeated,
        goldEarned: 0,
        playTime: gameStartTime != null
            ? DateTime.now().difference(gameStartTime!)
            : Duration.zero,
      ));
    }
  }

  // ── camera ─────────────────────────────────────────────────────────────────

  void _updateCamera3D(double dt) {
    final projected = IsoProjection.project(character3D.worldPos);
    final desired = Vector2(
      size.x * 0.5  - projected.x,
      size.y * 0.65 - projected.y,
    );
    final t = (GameConfig3D.cameraLerpSpeed * dt).clamp(0.0, 1.0);
    worldOriginOnScreen = Vector2(
      worldOriginOnScreen.x + (desired.x - worldOriginOnScreen.x) * t,
      worldOriginOnScreen.y + (desired.y - worldOriginOnScreen.y) * t,
    );
    camera.moveTo(Vector2.zero());
  }

  // ── combat ─────────────────────────────────────────────────────────────────

  void _processCombat3D(double dt) {
    if (!character3D.characterState.isAttacking) return;

    final attackAabb = AABB3D(
      minX: character3D.worldPos.x - GameConfig3D.attackRangeX,
      maxX: character3D.worldPos.x + GameConfig3D.attackRangeX,
      minY: character3D.worldPos.y,
      maxY: character3D.worldPos.y + GameConfig3D.characterSizeY,
      minZ: character3D.worldPos.z - GameConfig3D.attackRangeZ / 2,
      maxZ: character3D.worldPos.z + GameConfig3D.attackRangeZ,
    );

    for (final enemy in enemies3D) {
      if (enemy.characterState.health <= 0) continue;

      final enemyAabb = AABB3D.fromCenter(
        center: WorldPos(
          enemy.worldPos.x,
          enemy.worldPos.y + GameConfig3D.characterSizeY / 2,
          enemy.worldPos.z,
        ),
        sizeX: GameConfig3D.characterSizeX,
        sizeY: GameConfig3D.characterSizeY,
        sizeZ: GameConfig3D.characterSizeZ,
      );

      if (attackAabb.overlapsXYZ(enemyAabb)) {
        enemy.takeDamage3D(
          character3D.stats.attackDamage.toDouble(),
          knockback: WorldPos(
            (enemy.worldPos.x - character3D.worldPos.x) * 0.5,
            200.0,
            (enemy.worldPos.z - character3D.worldPos.z) * 0.5,
          ),
        );
      }
    }
  }

  // ── spawn ──────────────────────────────────────────────────────────────────

  void spawnEnemy3D({
    required String characterClass,
    required WorldPos spawnPos,
    double difficultyMult = 1.0,
  }) {
    final stats = _statsFor(characterClass)
      ..health    = (GameConfig.characterBaseHealth * difficultyMult).clamp(50, 300)
      ..maxHealth = (GameConfig.characterBaseHealth * difficultyMult).clamp(50, 300)
      ..attackDamage = (20 * difficultyMult).clamp(10, 80).toInt().toDouble();

    final id    = '${characterClass}_${enemies3D.length}';
    final enemy = EnemyCharacter3D(
      characterClass: characterClass,
      spawnPos:       spawnPos,
      stats:          stats,
      id:             id,
    );
    enemy.priority = IsoProjection.depthPriority(spawnPos) + 200;

    world.add(enemy);
    enemies3D.add(enemy);
    characterRegistry3D[id] = enemy;
  }

  void registerCharacter3D(GameCharacter3D char) {
    characterRegistry3D[char.uniqueId] = char;
  }

  CharacterStats _statsFor(String cls) {
    switch (cls.toLowerCase()) {
      case 'thief':  return ThiefStats();
      case 'wizard': return WizardStats();
      case 'trader': return TraderStats();
      default:       return KnightStats();
    }
  }
}
