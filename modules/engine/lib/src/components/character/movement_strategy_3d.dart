// modules/engine/lib/src/components/character/movement_strategy_3d.dart

import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';

import 'game_character_3d.dart';

// ── Abstract base ─────────────────────────────────────────────────────────────

abstract class MovementStrategy3D {
  const MovementStrategy3D();

  double get walkSpeed;
  double get runSpeed;
  double get jumpPower;
  double get doubleJumpPower;
  bool   get canDoubleJump;
  bool   get canDodge;
  double get dodgeSpeed;

  /// Apply movement to [char] given a normalised XZ [inputDir] (from joystick).
  void applyMovement(GameCharacter3D char, Vector2 inputDir, bool run, double dt);

  /// Perform the dodge in the input or current facing direction.
  void applyDodge(GameCharacter3D char, Vector2 inputDir);
}

// ── Knight ────────────────────────────────────────────────────────────────────

class KnightMovementStrategy3D extends MovementStrategy3D {
  const KnightMovementStrategy3D();

  @override double get walkSpeed       => 260.0;
  @override double get runSpeed        => 400.0;
  @override double get jumpPower       => 600.0;
  @override double get doubleJumpPower => 500.0;
  @override bool   get canDoubleJump   => false;   // heavy armour
  @override bool   get canDodge        => true;
  @override double get dodgeSpeed      => 700.0;

  @override
  void applyMovement(GameCharacter3D char, Vector2 inputDir, bool run, double dt) {
    final spd = run ? runSpeed : walkSpeed;
    if (inputDir.length > 0.1) {
      char.velocity.x = inputDir.x * spd;
      char.velocity.z = -inputDir.y * spd;      // joystick Y → −world Z
      char.facingAngle = math.atan2(-inputDir.y, inputDir.x);
    }
  }

  @override
  void applyDodge(GameCharacter3D char, Vector2 inputDir) {
    final dir = inputDir.length > 0.2
        ? inputDir.normalized()
        : Vector2(math.cos(char.facingAngle), math.sin(char.facingAngle));
    char.velocity.x  = dir.x * dodgeSpeed;
    char.velocity.z  = dir.y * dodgeSpeed;
    char.velocity.y  = 160.0; // slight hop
    char.characterState
      ..isDodging     = true
      ..dodgeCooldown = GameConfig.dodgeCooldown;
  }
}

// ── Thief ─────────────────────────────────────────────────────────────────────

class ThiefMovementStrategy3D extends MovementStrategy3D {
  const ThiefMovementStrategy3D();

  @override double get walkSpeed       => 340.0;
  @override double get runSpeed        => 540.0;
  @override double get jumpPower       => 650.0;
  @override double get doubleJumpPower => 560.0;
  @override bool   get canDoubleJump   => true;
  @override bool   get canDodge        => true;
  @override double get dodgeSpeed      => 900.0;

  @override
  void applyMovement(GameCharacter3D char, Vector2 inputDir, bool run, double dt) {
    final spd = run ? runSpeed : walkSpeed;
    if (inputDir.length > 0.1) {
      char.velocity.x = inputDir.x * spd;
      char.velocity.z = -inputDir.y * spd;
      char.facingAngle = math.atan2(-inputDir.y, inputDir.x);
    }
  }

  @override
  void applyDodge(GameCharacter3D char, Vector2 inputDir) {
    final dir = inputDir.length > 0.2
        ? inputDir.normalized()
        : Vector2(math.cos(char.facingAngle), math.sin(char.facingAngle));
    char.velocity.x = dir.x  * dodgeSpeed;
    char.velocity.z = -dir.y * dodgeSpeed;
    char.velocity.y = 220.0;
    char.characterState
      ..isDodging     = true
      ..dodgeCooldown = GameConfig.dodgeCooldown * 0.75; // faster cooldown
  }
}

// ── Wizard ────────────────────────────────────────────────────────────────────

class WizardMovementStrategy3D extends MovementStrategy3D {
  const WizardMovementStrategy3D();

  @override double get walkSpeed       => 240.0;
  @override double get runSpeed        => 380.0;
  @override double get jumpPower       => 580.0;
  @override double get doubleJumpPower => 600.0;   // wizard floats better
  @override bool   get canDoubleJump   => true;
  @override bool   get canDodge        => true;
  @override double get dodgeSpeed      => 750.0;

  @override
  void applyMovement(GameCharacter3D char, Vector2 inputDir, bool run, double dt) {
    final spd = run ? runSpeed : walkSpeed;

    // Wizard has a slight "float" — slower fall while airborne.
    if (!char.characterState.wasGrounded) {
      char.velocity.y = math.max(char.velocity.y, -600.0);
    }

    if (inputDir.length > 0.1) {
      char.velocity.x = inputDir.x * spd;
      char.velocity.z = -inputDir.y * spd;
      char.facingAngle = math.atan2(-inputDir.y, inputDir.x);
    }
  }

  @override
  void applyDodge(GameCharacter3D char, Vector2 inputDir) {
    final dir = inputDir.length > 0.2
        ? inputDir.normalized()
        : Vector2(math.cos(char.facingAngle), math.sin(char.facingAngle));
    char.velocity.x = dir.x  * dodgeSpeed;
    char.velocity.z = -dir.y * dodgeSpeed;
    char.velocity.y = 200.0;
    char.characterState
      ..isDodging     = true
      ..dodgeCooldown = GameConfig.dodgeCooldown;
  }
}

// ── Trader ────────────────────────────────────────────────────────────────────

class TraderMovementStrategy3D extends MovementStrategy3D {
  const TraderMovementStrategy3D();

  @override double get walkSpeed       => 300.0;
  @override double get runSpeed        => 450.0;
  @override double get jumpPower       => 610.0;
  @override double get doubleJumpPower => 500.0;
  @override bool   get canDoubleJump   => false;
  @override bool   get canDodge        => true;
  @override double get dodgeSpeed      => 800.0;

  @override
  void applyMovement(GameCharacter3D char, Vector2 inputDir, bool run, double dt) {
    final spd = run ? runSpeed : walkSpeed;
    if (inputDir.length > 0.1) {
      char.velocity.x = inputDir.x * spd;
      char.velocity.z = -inputDir.y * spd;
      char.facingAngle = math.atan2(-inputDir.y, inputDir.x);
    }
  }

  @override
  void applyDodge(GameCharacter3D char, Vector2 inputDir) {
    final dir = inputDir.length > 0.2
        ? inputDir.normalized()
        : Vector2(math.cos(char.facingAngle), math.sin(char.facingAngle));
    char.velocity.x = dir.x  * dodgeSpeed;
    char.velocity.z = -dir.y * dodgeSpeed;
    char.velocity.y = 180.0;
    char.characterState
      ..isDodging     = true
      ..dodgeCooldown = GameConfig.dodgeCooldown * 0.9;
  }
}

// ── Factory ───────────────────────────────────────────────────────────────────

MovementStrategy3D movementStrategy3DFor(String characterClass) =>
    switch (characterClass.toLowerCase()) {
      'knight' => const KnightMovementStrategy3D(),
      'thief'  => const ThiefMovementStrategy3D(),
      'wizard' => const WizardMovementStrategy3D(),
      'trader' => const TraderMovementStrategy3D(),
      _        => const KnightMovementStrategy3D(),
    };