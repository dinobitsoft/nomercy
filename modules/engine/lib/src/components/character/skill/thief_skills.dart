import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';

/// Shadow Strike — launch into the air and deal heavy damage on landing hit.
/// Works both on ground (auto-jump) and while already airborne.
class ShadowStrike extends Skill {
  ShadowStrike()
      : super(
    id: 'shadow_strike',
    name: 'Shadow Strike',
    description: 'Leap and slam into an enemy for heavy air damage.',
    icon: Icons.air,
    cooldownDuration: 7.0,
    staminaCost: 30,
  );

  @override
  SkillResult execute(GameCharacter character) {
    // Auto-jump if grounded
    if (character.characterState.groundPlatform != null) {
      character.velocity.y = -450;
      character.characterState.groundPlatform = null;
    }

    // Lock onto nearest enemy in front
    final targets =
    character.isPlayer ? character.game.enemies : [character.game.character];
    GameCharacter? nearest;
    double minDist = 400;
    for (final t in targets) {
      final dist = character.position.distanceTo(t.position);
      if (dist < minDist) { minDist = dist; nearest = t; }
    }

    if (nearest == null) return SkillResult.conditionNotMet;

    // Propel toward target
    final toTarget = nearest.position - character.position;
    character.velocity.x = toTarget.normalized().x * 600;
    character.facingRight = toTarget.x > 0;

    // Deal damage after a short travel window (50 ms)
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!character.isMounted || !nearest!.isMounted) return;
      final dist = character.position.distanceTo(nearest.position);
      if (dist < 160) {
        nearest.takeDamage(character.stats.attackDamage * 2.2);
        nearest.velocity.y = -200;

        character.game.eventBus.emit(ShowNotificationEvent(
          message: '🗡 SHADOW STRIKE!',
          color: Colors.green,
        ));
      }
    });

    return SkillResult.success;
  }
}

/// Smoke Bomb — brief invincibility + speed boost, resets dodge cooldown.
class SmokeBomb extends Skill {
  static const double _invincDuration = 1.5;

  SmokeBomb()
      : super(
    id: 'smoke_bomb',
    name: 'Smoke Bomb',
    description: 'Vanish briefly. Invincible for 1.5 s, dodge resets.',
    icon: Icons.cloud,
    cooldownDuration: 10.0,
    staminaCost: 20,
  );

  @override
  SkillResult execute(GameCharacter character) {
    character.characterState.dodgeCooldown = 0; // reset dodge immediately
    character.characterState.isDodging     = true;
    character.characterState.dodgeDuration = _invincDuration;

    character.game.eventBus.emit(ShowNotificationEvent(
      message: '💨 SMOKE BOMB!',
      color: Colors.grey,
    ));

    return SkillResult.success;
  }
}