import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Magic Burst — AoE explosion centered on the wizard, damages all nearby enemies.
class MagicBurst extends Skill {
  static const double _radius = 250.0;

  MagicBurst()
      : super(
    id: 'magic_burst',
    name: 'Magic Burst',
    description: 'AoE explosion. Damages all enemies within 250 px.',
    icon: Icons.flare,
    cooldownDuration: 9.0,
    staminaCost: 35,
  );

  @override
  SkillResult execute(GameCharacter character) {
    final targets =
    character.isPlayer ? character.game.enemies : [character.game.character];

    int hit = 0;
    for (final target in targets) {
      if (character.position.distanceTo(target.position) <= _radius) {
        target.takeDamage(character.stats.attackDamage * 1.8);
        // Radial knockback
        final away = (target.position - character.position).normalized();
        target.velocity
          ..x += away.x * 300
          ..y += -150;
        hit++;
      }
    }

    if (hit == 0) return SkillResult.conditionNotMet;

    // Spawn a burst visual
    _spawnBurstEffect(character);

    character.game.eventBus.emit(ShowNotificationEvent(
      message: '✨ MAGIC BURST! ($hit hit)',
      color: Colors.purpleAccent,
    ));

    return SkillResult.success;
  }

  void _spawnBurstEffect(GameCharacter character) {
    // Re-use ImpactEffect at the character center
    final effect = ImpactEffect(
      position: character.position.clone(),
      color: Colors.purple,
    );
    character.game.add(effect);
  }
}

/// Blink Teleport — instantly teleport a fixed distance in the facing direction.
class BlinkTeleport extends Skill {
  static const double _distance = 350.0;

  BlinkTeleport()
      : super(
    id: 'blink_teleport',
    name: 'Blink',
    description: 'Teleport 350 px forward, passing through enemies.',
    icon: Icons.swap_horiz,
    cooldownDuration: 8.0,
    staminaCost: 25,
  );

  @override
  SkillResult execute(GameCharacter character) {
    final dir    = character.facingRight ? 1.0 : -1.0;
    final target = character.position + Vector2(dir * _distance, 0);

    // Clamp to world bounds loosely
    character.position.x = target.x;

    // Velocity zeroed so no momentum carry
    character.velocity.x = 0;

    character.game.eventBus.emit(ShowNotificationEvent(
      message: '🌀 BLINK!',
      color: Colors.cyanAccent,
    ));

    return SkillResult.success;
  }
}