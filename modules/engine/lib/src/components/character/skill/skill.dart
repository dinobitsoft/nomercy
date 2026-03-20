import 'package:flutter/material.dart';

/// Result returned by Skill.execute so callers can react.
enum SkillResult {
  success,
  onCooldown,
  notEnoughStamina,
  conditionNotMet,
}

/// Abstract base for all character skills.
/// Each skill owns its cooldown timer — no external state needed.
abstract class Skill {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final double cooldownDuration;
  final double staminaCost;

  double _cooldownRemaining = 0;

  Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.cooldownDuration,
    required this.staminaCost,
  });

  bool get isReady => _cooldownRemaining <= 0;
  double get cooldownRemaining => _cooldownRemaining;

  /// 0.0 – 1.0 progress until ready. 1.0 = fully charged.
  double get chargeProgress =>
      cooldownDuration <= 0 ? 1.0 : 1.0 - (_cooldownRemaining / cooldownDuration);

  /// Called every game frame. Must be forwarded from GameCharacter.update().
  void update(double dt) {
    if (_cooldownRemaining > 0) _cooldownRemaining -= dt;
    if (_cooldownRemaining < 0) _cooldownRemaining = 0;
  }

  /// Try to execute this skill on [character].
  SkillResult activate(covariant dynamic character) {
    if (!isReady) return SkillResult.onCooldown;
    if (character.characterState.stamina < staminaCost) {
      return SkillResult.notEnoughStamina;
    }
    final result = execute(character);
    if (result == SkillResult.success) {
      _cooldownRemaining = cooldownDuration;
      character.characterState.stamina -= staminaCost;
    }
    return result;
  }

  /// Override to implement skill logic. Return [SkillResult.success] if the
  /// skill actually fired, any other value to abort (cooldown won't start).
  SkillResult execute(covariant dynamic character);

  void reset() => _cooldownRemaining = 0;
}