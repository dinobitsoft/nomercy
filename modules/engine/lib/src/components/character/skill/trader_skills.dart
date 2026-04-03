import 'dart:async' as da;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Poison Arrow — fires a single projectile that deals DoT over 3 seconds. POISON is not a skill. TODO: refactor
class PoisonArrow extends Skill {
  PoisonArrow()
      : super(
    id: 'poison_arrow',
    name: 'Poison Arrow',
    description: 'Fire a poisoned arrow. 15 damage/s for 3 s.',
    icon: Icons.vaccines,
    cooldownDuration: 8.0,
    staminaCost: 20,
  );

  @override
  SkillResult execute(GameCharacter character) {
    final dir = character.facingRight ? Vector2(1, 0) : Vector2(-1, 0);
    final proj = Projectile(
      position:   character.position.clone() + (character.facingRight ? Vector2(40,0) : Vector2(-40,0)),
      direction:  dir,
      damage:     character.stats.attackDamage * 0.5, // lower instant dmg
      owner:      character.isPlayer ? character : null,
      enemyOwner: character.isBot    ? character : null,
      color:      Colors.green,
      type:       'arrow',
    );
    proj.priority = 75;
    character.game.world.add(proj);
    character.game.projectiles.add(proj);

    // DoT: tick 6 times over 3 seconds
    _applyPoison(character, proj);

    character.game.eventBus.emit(ShowNotificationEvent(
      message: '☠ POISON ARROW!',
      color: Colors.greenAccent,
    ));

    return SkillResult.success;
  }

  void _applyPoison(GameCharacter shooter, Projectile projectile) {
    // Find who was hit by polling position for one frame — or just schedule
    // the DoT on any enemy that overlaps within 200 ms of firing.
    Future.delayed(const Duration(milliseconds: 200), () {
      final targets = shooter.isPlayer
          ? shooter.game.enemies
          : [shooter.game.character];

      for (final target in targets) {
        if (!target.isMounted) continue;
        if (shooter.game.projectiles.contains(projectile)) continue; // not hit yet
        // projectile already removed = it hit something; apply poison broadly
      }

      // Fallback: apply to closest enemy in front within range
      final inRange = (shooter.isPlayer ? shooter.game.enemies : [shooter.game.character])
          .where((t) => t.isMounted && shooter.position.distanceTo(t.position) < 500)
          .toList();
      if (inRange.isEmpty) return;

      final target = inRange.reduce((a, b) =>
      shooter.position.distanceTo(a.position) <
          shooter.position.distanceTo(b.position)
          ? a
          : b);

      int ticks = 0;
      da.Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (ticks >= 6 || !target.isMounted) { timer.cancel(); return; }
        target.takeDamage(7.5); // 15 dmg/s at 2 ticks/s
        ticks++;
      });
    });
  }
}

/// Barrage Shot — rapidly fire 6 arrows in 0.8 seconds.
class BarrageShot extends Skill {
  BarrageShot()
      : super(
    id: 'barrage_shot',
    name: 'Barrage Shot',
    description: 'Unleash 6 arrows in 0.8 s.',
    icon: Icons.multiple_stop,
    cooldownDuration: 11.0,
    staminaCost: 30,
  );

  @override
  SkillResult execute(GameCharacter character) {
    character.game.eventBus.emit(ShowNotificationEvent(
      message: '🏹 BARRAGE!',
      color: Colors.orange,
    ));

    for (int i = 0; i < 6; i++) {
      Future.delayed(Duration(milliseconds: i * 130), () {
        if (!character.isMounted) return;
        final spread = (i - 2.5) * 0.08;
        final base   = character.facingRight ? Vector2(1, 0) : Vector2(-1, 0);
        final dir    = Vector2(base.x, base.y)..rotate(spread);
        final proj   = Projectile(
          position:   character.position.clone(),
          direction:  dir,
          damage:     character.stats.attackDamage * 0.7,
          owner:      character.isPlayer ? character : null,
          enemyOwner: character.isBot    ? character : null,
          color:      Colors.brown,
          type:       'arrow',
        );
        proj.priority = 75;
        character.game.world.add(proj);
        character.game.projectiles.add(proj);
      });
    }

    return SkillResult.success;
  }
}