// modules/engine/lib/src/components/character/player_character_3d.dart

import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

import '../../bot/bot_controller_3d.dart';
import '../../bot/bot_personality_3d.dart';
import 'game_character_3d.dart';
import 'movement_strategy_3d.dart';

// ── Player character ──────────────────────────────────────────────────────────

class PlayerCharacter3D extends GameCharacter3D {
  @override final ActionStrategy   actionStrategy;
  @override final MovementStrategy movementStrategy; // 2D legacy — not used in 3D path
  final MovementStrategy3D movementStrategy3D;

  PlayerCharacter3D({
    required String characterClass,
    required WorldPos spawnPos,
    required CharacterStats stats,
  })  : actionStrategy    = actionStrategyFor(characterClass),
        movementStrategy  = movementStrategyFor(characterClass),
        movementStrategy3D = movementStrategy3DFor(characterClass),
        super(
        stats:      stats,
        playerType: PlayerType.human,
        uniqueId:   'player_main',
        initialPos: spawnPos,
      );

  @override
  void updateHumanControl(double dt) {
    if (characterState.isStunned || characterState.isLanding ||
        characterState.isDodging) return;

    final gp      = game.gamepadManager;
    final gpDir   = gp.joystickDelta;
    final stick   = gpDir.length > 0.1 ? gpDir : game.joystick.relativeDelta;

    final isRun = stick.length > 0.65;

    // Flip stick.y so joystick-up moves character up on screen (-Z in world).
    // Bot AI passes world-space inputs directly and handles its own sign, so
    // this correction is applied only here at the player call site.
    final correctedStick = Vector2(stick.x, -stick.y);

    if (!characterState.isAttacking) {
      movementStrategy3D.applyMovement(this, correctedStick, isRun, dt);
    }

    // Jump
    final jumpJust = gp.isJumpPressed && !_prevJumpInput;
    _prevJumpInput = gp.isJumpPressed;
    if (jumpJust) performJump3D();

    // Dodge
    if (gp.isDodgeJustPressed() &&
        groundPlatform != null &&
        characterState.dodgeCooldown <= 0 &&
        movementStrategy3D.canDodge) {
      movementStrategy3D.applyDodge(this, correctedStick);
    }

    // Attack
    if (gp.isAttackPressed && !characterState.isAttacking &&
        characterState.attackCooldown <= 0) {
      performAttack3D();
    }
  }

  bool _prevJumpInput = false;
}

// ── Enemy character (bot) ─────────────────────────────────────────────────────

class EnemyCharacter3D extends GameCharacter3D {
  @override final ActionStrategy   actionStrategy;
  @override final MovementStrategy movementStrategy;
  final MovementStrategy3D movementStrategy3D;

  final BotPersonality3D personality;
  late final BotController3D _ai;

  EnemyCharacter3D({
    required String characterClass,
    required WorldPos spawnPos,
    required super.stats,
    required String id,
    BotPersonality3D? personality,
  })  : personality        = personality ?? _randomPersonality(),
        actionStrategy     = actionStrategyFor(characterClass),
        movementStrategy   = movementStrategyFor(characterClass),
        movementStrategy3D = movementStrategy3DFor(characterClass),
        super(
        playerType: PlayerType.bot,
        uniqueId:   id,
        initialPos: spawnPos,
      ) {
    _ai = AiBotRegistry.create(this.personality);
  }

  @override
  void updateBotControl(double dt) {
    if (game.character.characterState.health <= 0) return;
    _ai.update(this, movementStrategy3D, dt);
  }

  @override
  void takeDamage3D(double damage, {WorldPos? knockback}) {
    super.takeDamage3D(damage, knockback: knockback);
    _ai.onDamageTaken(this, damage);
  }

  @override
  void onBeforeRemove() {
    game.enemies.remove(this);
    game.characterRegistry.remove(uniqueId);
    game.enemiesDefeated++;
  }

  static BotPersonality3D _randomPersonality() {
    const all = BotPersonality3D.values;
    return all[math.Random().nextInt(all.length)];
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

extension on WorldPos {
  double lengthXZTo(WorldPos other) {
    final dx = other.x - x;
    final dz = other.z - z;
    final sq = dx * dx + dz * dz;
    return sq < 1e-6 ? 0 : math.sqrt(sq);
  }
}

ActionStrategy actionStrategyFor(String cls) =>
    switch (cls.toLowerCase()) {
      'knight' => KnightActionStrategy(),
      'thief'  => ThiefActionStrategy(),
      'wizard' => WizardActionStrategy(),
      'trader' => TraderActionStrategy(),
      _        => KnightActionStrategy(),
    };

MovementStrategy movementStrategyFor(String cls) =>
    switch (cls.toLowerCase()) {
      'knight' => KnightMovementStrategy(),
      'thief'  => ThiefMovementStrategy(),
      'wizard' => WizardMovementStrategy(),
      'trader' => TraderMovementStrategy(),
      _        => KnightMovementStrategy(),
    };