import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';

/// Shield Bash — short forward charge that stuns the first enemy hit.
class ShieldBash extends Skill {
  ShieldBash()
      : super(
    id: 'shield_bash',
    name: 'Shield Bash',
    description: 'Charge forward, stunning the first enemy hit.',
    icon: Icons.shield,
    cooldownDuration: 6.0,
    staminaCost: 25,
  );

  @override
  SkillResult execute(GameCharacter character) {
    if (character.characterState.groundPlatform == null) {
      return SkillResult.conditionNotMet; // grounded only
    }

    // Lunge velocity
    final dir = character.facingRight ? 1.0 : -1.0;
    character.velocity.x = dir * character.stats.dexterity * 20;

    // Hit check with a generous range (bash arc)
    final targets =
    character.isPlayer ? character.game.enemies : [character.game.character];

    for (final target in targets) {
      final dist = character.position.distanceTo(target.position);
      if (dist > 200) continue;
      final dx = target.position.x - character.position.x;
      if ((character.facingRight && dx < 0) || (!character.facingRight && dx > 0)) continue;

      target.takeDamage(character.stats.attackDamage * 0.6);
      target.characterState
        ..isStunned    = true
        ..stunDuration = 1.2;

      character.game.eventBus.emit(CharacterStunnedEvent(
        characterId: target.stats.name,
        position: target.position.clone(),
        duration: 1.2,
        source: 'shield_bash',
      ));

      character.game.eventBus.emit(ShowNotificationEvent(
        message: '🛡 SHIELD BASH!',
        color: Colors.blueAccent,
      ));
      break; // only first target
    }

    return SkillResult.success;
  }
}

/// Berserker Rush — brief period of doubled attack damage and immunity to knockback.
class BerserkerRush extends Skill {
  static const double _duration = 4.0;

  BerserkerRush()
      : super(
    id: 'berserker_rush',
    name: 'Berserker Rush',
    description: 'Double attack damage for 4 seconds. Knockback immune.',
    icon: Icons.local_fire_department,
    cooldownDuration: 14.0,
    staminaCost: 30,
  );

  @override
  SkillResult execute(GameCharacter character) {
    // Temporarily boost attackDamage; a ticking buff restores it after duration.
    final boost = character.stats.attackDamage;
    character.stats.attackDamage += boost;

    character.game.eventBus.emit(ShowNotificationEvent(
      message: '⚡ BERSERKER RUSH!',
      color: Colors.redAccent,
    ));

    // Schedule revert via Future — simple and avoids a dedicated buff system.
    Future.delayed(
      Duration(milliseconds: (_duration * 1000).toInt()),
          () {
        if (character.isMounted) character.stats.attackDamage -= boost;
      },
    );

    return SkillResult.success;
  }
}