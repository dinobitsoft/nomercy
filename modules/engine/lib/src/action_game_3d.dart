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

import 'bot/bot_personality_3d.dart';
import 'components/character/game_character_3d.dart';
import 'components/character/player_character_3d.dart';
import 'components/obstacle/obstacle_3d.dart';
import 'components/platform/game_platform_3d.dart';
import 'components/projectile/projectile_3d.dart';

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

  /// All 3D platforms — used for physics collision (top-landing only).
  final List<GamePlatform3D>  platforms3D  = [];

  /// All 3D obstacles — solid boxes; block lateral (XZ) movement AND top-landing.
  final List<Obstacle3D>      obstacles3D  = [];

  /// Live 3D projectiles.
  final List<Projectile3D>    projectiles3D = [];

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

    // Aim joystick (bottom-right) replaces the attack button.
    // Drag to aim + auto-fire; jump button stays to its left.
    camera.viewport.add(_AimJoystick3D(game: this));
    camera.viewport.add(_JumpButton3D(game: this));

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
    BotPersonality3D? personality,
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
      personality:    personality,
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

// ── Aim joystick (replaces attack button) ────────────────────────────────────
//
// Drag in any direction to aim and auto-fire.
// The dragged direction maps to world XZ: right = +X, up(screen) = +Z(forward).
// Elevation is computed automatically so shots arc correctly from any height.

class _AimJoystick3D extends PositionComponent
    with DragCallbacks, HasGameReference<ActionGame3D> {

  static const double _bgRadius   = 50.0;
  static const double _knobRadius = 22.0;
  // Centre of the component in screen space (from bottom-right corner).
  static const double _marginR    = 60.0;
  static const double _marginB    = 60.0;

  /// Current knob offset from component centre (clamped to _bgRadius).
  Vector2 _delta    = Vector2.zero();
  /// Accumulated local knob position (updated via start + delta chain).
  Vector2 _knobLocal = Vector2.zero();
  bool    _held     = false;

  _AimJoystick3D({required ActionGame3D game})
      : super(
          anchor:   Anchor.center,
          size:     Vector2.all(_bgRadius * 2),
          priority: 200,
        );

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    position = Vector2(gameSize.x - _marginR, gameSize.y - _marginB);
  }

  // ── drag events ────────────────────────────────────────────────────────────

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _held      = true;
    _knobLocal = event.localPosition.clone();
    _updateDelta(_knobLocal);
    _tryFire();
    event.handled = true;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    // DragUpdateEvent provides localDelta, not localPosition — accumulate.
    _knobLocal += event.localDelta;
    _updateDelta(_knobLocal);
    event.handled = true;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _release();
    event.handled = true;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _release();
    event.handled = true;
  }

  void _updateDelta(Vector2 localPos) {
    // localPos is relative to component top-left; centre is at (_bgRadius, _bgRadius).
    final d = localPos - Vector2(_bgRadius, _bgRadius);
    _delta = d.length > _bgRadius ? (d.normalized()..scale(_bgRadius)) : d.clone();
    // Pass normalised aim input to character (-1..+1 on each axis).
    game.character.aimInput = _delta / _bgRadius;
  }

  void _release() {
    _held  = false;
    _delta = Vector2.zero();
    game.character.aimInput = Vector2.zero();
  }

  void _tryFire() {
    final char = game.character;
    if (char.characterState.isAttacking)     return;
    if (char.characterState.attackCooldown > 0) return;
    char.performAttack3D();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_held) _tryFire(); // performAttack3D checks cooldown internally
  }

  // ── render ─────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final cx  = _bgRadius;
    final cy  = _bgRadius;
    final cs  = game.character.characterState;
    final ready = cs.attackCooldown <= 0 && cs.stamina >= 15;

    // Background shadow ring.
    canvas.drawCircle(Offset(cx, cy), _bgRadius + 3,
        Paint()..color = Colors.black.withOpacity(0.30));

    // Background fill.
    canvas.drawCircle(Offset(cx, cy), _bgRadius,
        Paint()..color = Colors.red.withOpacity(_held ? 0.22 : (ready ? 0.12 : 0.07)));

    // Cardinal direction tick marks.
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final d in [Offset(0, -1), Offset(0, 1), Offset(-1, 0), Offset(1, 0)]) {
      canvas.drawLine(
        Offset(cx + d.dx * 18, cy + d.dy * 18),
        Offset(cx + d.dx * (_bgRadius - 6), cy + d.dy * (_bgRadius - 6)),
        tickPaint,
      );
    }

    // Knob.
    final kx = cx + _delta.x;
    final ky = cy + _delta.y;
    canvas.drawCircle(Offset(kx + 1.5, ky + 1.5), _knobRadius,
        Paint()..color = Colors.black.withOpacity(0.22));
    canvas.drawCircle(Offset(kx, ky), _knobRadius,
        Paint()..color = Colors.red
            .withOpacity(_held ? 0.88 : (ready ? 0.65 : 0.35)));

    // Sword icon on knob.
    final iconPaint = Paint()
      ..color      = Colors.white.withOpacity(ready ? 0.90 : 0.45)
      ..strokeWidth = 3.0
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round;
    canvas.drawLine(Offset(kx, ky - 14), Offset(kx, ky + 16), iconPaint);
    canvas.drawLine(Offset(kx - 9, ky + 2), Offset(kx + 9, ky + 2), iconPaint);

    // Aim arrow shown while dragging (outside the background circle).
    if (_held && _delta.length > 8) {
      final dir   = _delta.normalized();
      final start = Offset(cx + dir.x * (_bgRadius + 6),
                           cy + dir.y * (_bgRadius + 6));
      final end   = Offset(cx + dir.x * (_bgRadius + 20),
                           cy + dir.y * (_bgRadius + 20));
      final arrowPaint = Paint()
        ..color      = Colors.red.withOpacity(0.75)
        ..strokeWidth = 2.5
        ..strokeCap  = StrokeCap.round;
      canvas.drawLine(start, end, arrowPaint);
      // Arrowhead.
      final perp = Offset(-dir.y, dir.x);
      canvas.drawPath(
        Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - dir.x * 7 + perp.dx * 4,
                   end.dy - dir.y * 7 + perp.dy * 4)
          ..lineTo(end.dx - dir.x * 7 - perp.dx * 4,
                   end.dy - dir.y * 7 - perp.dy * 4)
          ..close(),
        Paint()..color = Colors.red.withOpacity(0.75),
      );
    }

    // Cooldown arc overlay.
    if (cs.attackCooldown > 0) {
      final sweep = (cs.attackCooldown / GameConfig.attackCooldown)
          .clamp(0.0, 1.0) * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: _bgRadius),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color      = Colors.white.withOpacity(0.22)
          ..strokeWidth = 4
          ..style      = PaintingStyle.stroke,
      );
    }
  }
}

// ── On-screen jump button ─────────────────────────────────────────────────────

class _JumpButton3D extends PositionComponent
    with TapCallbacks, HasGameReference<ActionGame3D> {

  static const double _radius = 40.0;
  static const double _margin = 50.0;
  // Sits directly to the left of the attack button with a small gap.
  static const double _gap    = 20.0;

  bool _pressed = false;

  _JumpButton3D({required ActionGame3D game})
      : super(
          anchor: Anchor.center,
          size: Vector2.all(_radius * 2),
          priority: 200,
        );

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    // Mirror the attack button X, then step one button-width + gap further left.
    position = Vector2(
      gameSize.x - _margin - _radius - _gap - _radius * 2,
      gameSize.y - _margin - _radius,
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    _pressed = true;
    game.character.performJump3D();
  }

  @override
  void onTapUp(TapUpEvent event) => _pressed = false;

  @override
  void onTapCancel(TapCancelEvent event) => _pressed = false;

  @override
  void render(Canvas canvas) {
    final cs       = game.character.characterState;
    final grounded = game.character.groundPlatform != null ||
        game.character.groundObstacle != null ||
        // ignore private _onInfiniteFloor — proxy via isAirborne instead
        !cs.isAirborne;
    final canJump  = (grounded || (!cs.hasDoubleJumped && cs.canDoubleJump)) &&
        cs.stamina >= GameConfig3D.jumpStaminaCost;

    final cx = _radius;
    final cy = _radius;

    // Outer glow when jump is available.
    if (canJump) {
      canvas.drawCircle(
        Offset(cx, cy),
        _radius + 6,
        Paint()..color = Colors.cyanAccent.withOpacity(_pressed ? 0.7 : 0.28),
      );
    }

    // Button background — cyan/blue family to distinguish from red attack.
    canvas.drawCircle(
      Offset(cx, cy),
      _radius,
      Paint()..color = _pressed
          ? const Color(0xFF00bcd4).withOpacity(0.90)
          : const Color(0xFF0288d1).withOpacity(canJump ? 0.65 : 0.28),
    );

    // Up-arrow icon.
    final iconPaint = Paint()
      ..color      = Colors.white.withOpacity(canJump ? 0.95 : 0.45)
      ..strokeWidth = 4.0
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final arrowPath = Path()
      ..moveTo(cx - 13, cy + 10)   // bottom-left
      ..lineTo(cx,      cy - 14)   // apex
      ..lineTo(cx + 13, cy + 10)   // bottom-right
      ..moveTo(cx,      cy - 14)   // stem top
      ..lineTo(cx,      cy + 14);  // stem bottom
    canvas.drawPath(arrowPath, iconPaint);

    // Double-jump indicator: small dot above the arrow when airborne + can still jump.
    if (!grounded && !cs.hasDoubleJumped && cs.canDoubleJump) {
      canvas.drawCircle(
        Offset(cx, cy - 26),
        4,
        Paint()..color = Colors.cyanAccent.withOpacity(0.85),
      );
    }

    // Stamina arc (mirrors the cooldown arc on the attack button).
    final staminaFrac = (cs.stamina / cs.maxStamina).clamp(0.0, 1.0);
    if (staminaFrac < 1.0) {
      // Grey background ring.
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: _radius),
        -math.pi / 2,
        math.pi * 2,
        false,
        Paint()
          ..color      = Colors.white.withOpacity(0.10)
          ..strokeWidth = 4
          ..style      = PaintingStyle.stroke,
      );
      // Filled portion.
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: _radius),
        -math.pi / 2,
        staminaFrac * math.pi * 2,
        false,
        Paint()
          ..color      = Colors.cyanAccent.withOpacity(0.45)
          ..strokeWidth = 4
          ..style      = PaintingStyle.stroke,
      );
    }
  }
}