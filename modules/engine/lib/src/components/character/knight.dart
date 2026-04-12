import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Knight extends GameCharacter {
  final EventBus _eventBus = EventBus();

  @override late final ActionStrategy  actionStrategy  = KnightActionStrategy();
  @override late final MovementStrategy movementStrategy = KnightMovementStrategy();

  Knight({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
    super.customId,
  }) : super(botTactic: botTactic, stats: KnightStats());

  @override
  void updateBotControl(double dt) {
    if (botTactic != null &&
        !characterState.isStunned &&
        !characterState.isLanding &&
        characterState.health > 0) {
      botTactic!.execute(this, game.character, dt);
      _botDefensiveMechanics();
    }
  }

  void _botDefensiveMechanics() {
    final dist = position.distanceTo(game.character.position);
    final projectiles = game.projectiles
        .where((p) => p.owner != null && position.distanceTo(p.position) < 150 && characterState.dodgeCooldown <= 0)
        .toList();
    if (projectiles.isNotEmpty && characterState.stamina > 20) {
      dodge(Vector2(projectiles.first.direction.x > 0 ? -1 : 1, 0));
    }
    if (dist < 150 && game.character.characterState.isAttacking &&
        !characterState.isDodging && characterState.stamina > 30) {
      startBlock();
    } else if (characterState.isBlocking &&
        (!game.character.characterState.isAttacking || dist > 150)) {
      stopBlock();
    }
  }

  @override
  void attack() {
    // Delegate to weapon if equipped, otherwise melee default
    if (equippedWeapon != null) { performWeaponAttack(); return; }
    if (!prepareAttackWithEvent()) return;

    final targets = isPlayer ? game.enemies : [game.character];
    for (final target in targets) {
      final dist  = position.distanceTo(target.position);
      final range = stats.attackRange * 30 * (1 + characterState.comboCount * 0.1);
      if (dist >= range) continue;
      final dx = target.position.x - position.x;
      if (dist > 50 && !((facingRight && dx > 0) || (!facingRight && dx < 0))) continue;
      game.combatSystem.processAttack(attacker: this, target: target, attackType: 'melee');
      target.velocity.x += (facingRight ? 1 : -1) * 150;
      if (characterState.comboCount >= 3) target.velocity.y = -100;
    }
  }
}

class KnightStats extends CharacterStats {
  KnightStats() : super(
    name: 'Knight', power: 15, magic: 5, dexterity: 8, intelligence: 7,
    weaponName: 'Sword Slash', attackRange: 2.0, attackDamage: 15,
    color: Colors.blue,
  );
}