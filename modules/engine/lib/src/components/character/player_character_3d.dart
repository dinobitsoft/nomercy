// modules/engine/lib/src/components/character/player_character_3d.dart

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

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

    final gp = game.gamepadManager;
    Vector2 stick;

    if (gp.isGamepadConnected && gp.hasMovementInput()) {
      stick = gp.getJoystickDirection();
    } else {
      stick = game.joystick.relativeDelta;
    }

    final isRun = stick.length > 0.65;

    if (!characterState.isAttacking) {
      movementStrategy3D.applyMovement(this, stick, isRun, dt);
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
      movementStrategy3D.applyDodge(this, stick);
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

  double _aiTimer = 0;
  static const double _aiInterval = 0.18;

  EnemyCharacter3D({
    required String characterClass,
    required WorldPos spawnPos,
    required CharacterStats stats,
    required String id,
  })  : actionStrategy     = actionStrategyFor(characterClass),
        movementStrategy   = movementStrategyFor(characterClass),
        movementStrategy3D = movementStrategy3DFor(characterClass),
        super(
        stats:      stats,
        playerType: PlayerType.bot,
        uniqueId:   id,
        initialPos: spawnPos,
      );

  @override
  void updateBotControl(double dt) {
    _aiTimer += dt;
    if (_aiTimer < _aiInterval) return;
    _aiTimer = 0;

    final player = game.character3D;
    if (player.characterState.health <= 0) return;

    final dx = player.worldPos.x - worldPos.x;
    final dz = player.worldPos.z - worldPos.z;
    final dist = worldPos.lengthXZTo(player.worldPos);

    // Chase player
    if (dist > 80) {
      final input = Vector2(dx, -dz) // flip Z for input convention
        ..normalize();
      movementStrategy3D.applyMovement(this, input, dist > 400, dt);
    }

    // Jump over obstacles / gaps
    if (groundPlatform == null && characterState.wasGrounded) {
      performJump3D();
    }

    // Attack when in range
    if (dist < GameConfig3D.attackRangeZ + 40 &&
        !characterState.isAttacking &&
        characterState.attackCooldown <= 0) {
      performAttack3D();
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

extension on WorldPos {
  double lengthXZTo(WorldPos other) {
    final dx = other.x - x;
    final dz = other.z - z;
    return (dx * dx + dz * dz) < 1e-6 ? 0 : (dx * dx + dz * dz);
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