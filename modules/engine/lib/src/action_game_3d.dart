// modules/engine/lib/src/action_game_3d.dart

import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepad/gamepad.dart';
import 'package:service/service.dart';

import 'components/character/game_character_3d.dart';
import 'components/character/player_character_3d.dart';
import 'components/platform/game_platform_3d.dart';

/// Top-level FlameGame for the 3D platformer.
///
/// Key differences from [ActionGame]:
///   • [platforms3D] replaces [platforms] — 3D AABB boxes.
///   • [PlayerCharacter3D] / [EnemyCharacter3D] hold a [WorldPos].
///   • [InfiniteWorldSystem3D] generates chunks along Z axis.
///   • [worldOriginOnScreen] maps world (0,0,0) to a fixed screen point so
///     the [IsoProjection] always aligns with camera position.
///   • Camera follows the *projected* player position.
class ActionGame3D extends FlameGame
    with HasCollisionDetection, TapCallbacks, KeyboardEvents {

  // ── systems ────────────────────────────────────────────────────────────────
  final EventBus    eventBus    = EventBus();
  late CombatSystem combatSystem;
  late AudioSystem  audioSystem;

  final List<EventSubscription> _subscriptions = [];

  // ── game state ─────────────────────────────────────────────────────────────
  final String selectedCharacterClass;
  final String mapName;
  final GameMode gameMode;
  final bool procedural;
  final MapGeneratorConfig? mapConfig;
  final bool enableMultiplayer;

  late PlayerCharacter3D character;
  final List<EnemyCharacter3D>   enemies     = [];
  final Map<String, GameCharacter3D> characterRegistry = {};

  /// All 3D platforms — used for physics collision.
  final List<GamePlatform3D> platforms3D = [];

  final List<Projectile> projectiles = [];
  final List<Item>       inventory   = [];
  Weapon? equippedWeapon;

  late JoystickComponent joystick;

  InfiniteWorldSystem3D? _worldSystem;

  bool isGameOver   = false;
  int  enemiesDefeated = 0;
  DateTime? gameStartTime;

  final GamepadManager gamepadManager = GamepadManager();

  // ── camera 3D state ────────────────────────────────────────────────────────

  /// The screen position that maps to world (0,0,0).
  /// Updated each frame as the camera follows the player.
  Vector2 worldOriginOnScreen = Vector2.zero();

  /// Camera lag target — lerped toward projected player position.
  Vector2 _cameraTarget = Vector2.zero();

  ActionGame3D({
    required this.selectedCharacterClass,
    required this.gameMode,
    this.mapName     = 'level_1',
    this.procedural  = false,
    this.mapConfig   = null,
    this.enableMultiplayer = false,
  });

  // ── onLoad ─────────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    gameStartTime = DateTime.now();

    // Systems
    combatSystem = CombatSystem();
    audioSystem  = AudioSystem();

    _setupEventListeners();
    add(gamepadManager);

    // Camera: topLeft anchor so Flame world coords == screen coords (1:1).
    // worldOriginOnScreen handles the logical centering via manual projection.
    camera.viewfinder.zoom   = 1.0;
    camera.viewfinder.anchor = Anchor.topLeft;

    // World origin starts at screen centre (virtual 640×360).
    worldOriginOnScreen = size / 2;
    _cameraTarget       = worldOriginOnScreen.clone();

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
    final stats    = _statsForClass(selectedCharacterClass);

    character = PlayerCharacter3D(
      characterClass: selectedCharacterClass,
      spawnPos:       spawnPos,
      stats:          stats,
    );
    character.priority = IsoProjection.depthPriority(spawnPos) + 200;
    world.add(character);
    characterRegistry['player_main'] = character;

    // 3D world.
    _worldSystem = InfiniteWorldSystem3D(game: this);
    _worldSystem!.initialize();

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

    // On-screen attack button (bottom-right).
    camera.viewport.add(_AttackButton3D(game: this));

    // Start music.
    audioSystem.playMusic('battle_theme');
  }

  // ── update ─────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (isGameOver) return;

    // Advance world chunks.
    _worldSystem?.update(dt, character.worldPos);

    // Camera: follow projected player position with lerp.
    _updateCamera3D(dt);

    // Combat hit detection.
    _processCombat3D(dt);

    // Game-over check.
    if (character.characterState.health <= 0 && !isGameOver) {
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
    // Project player to screen, then offset so they appear at 50%/65%.
    final projectedPlayer = IsoProjection.project(character.worldPos);

    // worldOriginOnScreen drifts so that projectedPlayer stays at
    // (size.x * 0.5, size.y * 0.65).
    final desiredOrigin = Vector2(
      size.x * 0.5  - projectedPlayer.x,
      size.y * 0.65 - projectedPlayer.y,
    );

    // Lerp for smooth follow.
    worldOriginOnScreen = Vector2(
      _lerp(worldOriginOnScreen.x, desiredOrigin.x, GameConfig3D.cameraLerpSpeed * dt),
      _lerp(worldOriginOnScreen.y, desiredOrigin.y, GameConfig3D.cameraLerpSpeed * dt),
    );

    // Move Flame camera to match (camera at world origin in Flame space = 0,0).
    camera.moveTo(Vector2.zero());
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0, 1);

  // ── combat ─────────────────────────────────────────────────────────────────

  void _processCombat3D(double dt) {
    if (!character.characterState.isAttacking) return;

    final attackAabb = AABB3D(
      minX: character.worldPos.x - GameConfig3D.attackRangeX,
      maxX: character.worldPos.x + GameConfig3D.attackRangeX,
      minY: character.worldPos.y,
      maxY: character.worldPos.y + GameConfig3D.characterSizeY,
      minZ: character.worldPos.z - GameConfig3D.attackRangeZ / 2,
      maxZ: character.worldPos.z + GameConfig3D.attackRangeZ,
    );

    for (final enemy in enemies) {
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
          character.stats.attackDamage.toDouble(),
          knockback: WorldPos(
            (enemy.worldPos.x - character.worldPos.x) * 0.5,
            200.0,
            (enemy.worldPos.z - character.worldPos.z) * 0.5,
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
    final stats = _statsForClass(characterClass)
      ..health    = (GameConfig.characterBaseHealth * difficultyMult).clamp(50, 300)
      ..maxHealth = (GameConfig.characterBaseHealth * difficultyMult).clamp(50, 300)
      ..attackDamage = (20 * difficultyMult).clamp(10, 80).toInt().toDouble();

    final id    = '${characterClass}_${enemies.length}';
    final enemy = EnemyCharacter3D(
      characterClass: characterClass,
      spawnPos:       spawnPos,
      stats:          stats,
      id:             id,
    );
    enemy.priority = IsoProjection.depthPriority(spawnPos) + 200;

    world.add(enemy);
    enemies.add(enemy);
    characterRegistry[id] = enemy;
  }

  // ── registration ───────────────────────────────────────────────────────────

  void registerCharacter3D(GameCharacter3D char) {
    characterRegistry[char.uniqueId] = char;
  }

  CharacterStats _statsForClass(String cls) {
    switch (cls.toLowerCase()) {
      case 'thief':  return ThiefStats();
      case 'wizard': return WizardStats();
      case 'trader': return TraderStats();
      default:       return KnightStats();
    }
  }

  // ── input ──────────────────────────────────────────────────────────────────

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keys) {
    gamepadManager.onKeyEvent(event, keys);
    return KeyEventResult.handled;
  }

  // ── events ─────────────────────────────────────────────────────────────────

  void _setupEventListeners() {
    _subscriptions.add(
      eventBus.on<GameOverEvent>((e) => _handleGameOver(e)),
    );
  }

  void _handleGameOver(GameOverEvent e) {
    isGameOver = true;
  }

  @override
  void onRemove() {
    for (final s in _subscriptions) s.cancel();
    super.onRemove();
  }
}

// ── On-screen attack button ───────────────────────────────────────────────────

class _AttackButton3D extends PositionComponent
    with TapCallbacks, HasGameReference<ActionGame3D> {

  static const double _radius = 40.0;
  static const double _margin = 50.0;

  bool _pressed = false;

  _AttackButton3D({required ActionGame3D game})
      : super(
          anchor: Anchor.center,
          size: Vector2.all(_radius * 2),
          priority: 200,
        );

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    position = Vector2(gameSize.x - _margin - _radius, gameSize.y - _margin - _radius);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _pressed = true;
    game.character.performAttack3D();
  }

  @override
  void onTapUp(TapUpEvent event) => _pressed = false;

  @override
  void onTapCancel(TapCancelEvent event) => _pressed = false;

  @override
  void render(Canvas canvas) {
    final cs = game.character.characterState;
    final ready = cs.attackCooldown <= 0 && cs.stamina >= 15;

    // Glow ring when ready.
    if (ready) {
      canvas.drawCircle(
        Offset(_radius, _radius),
        _radius + 6,
        Paint()..color = Colors.red.withOpacity(_pressed ? 0.6 : 0.25),
      );
    }

    // Button background.
    canvas.drawCircle(
      Offset(_radius, _radius),
      _radius,
      Paint()..color = (_pressed
          ? Colors.red.withOpacity(0.85)
          : Colors.red.withOpacity(ready ? 0.65 : 0.30)),
    );

    // Sword icon (drawn as a simple cross shape).
    final iconPaint = Paint()
      ..color = Colors.white.withOpacity(ready ? 0.95 : 0.5)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = _radius;
    final cy = _radius;
    // Blade (vertical).
    canvas.drawLine(Offset(cx, cy - 20), Offset(cx, cy + 22), iconPaint);
    // Guard (horizontal).
    canvas.drawLine(Offset(cx - 13, cy + 2), Offset(cx + 13, cy + 2), iconPaint);

    // Cooldown arc overlay.
    if (cs.attackCooldown > 0) {
      final maxCd = GameConfig.attackCooldown;
      final sweep = (cs.attackCooldown / maxCd).clamp(0.0, 1.0) * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: _radius),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = Colors.white.withOpacity(0.25)
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke,
      );
    }
  }
}