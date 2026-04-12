import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Thief extends GameCharacter {
  final EventBus _eventBus = EventBus();

  @override late final ActionStrategy  actionStrategy  = ThiefActionStrategy();
  @override late final MovementStrategy movementStrategy = ThiefMovementStrategy();

  Thief({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
    super.customId,
  }) : super(botTactic: botTactic, stats: ThiefStats());

  @override
  void updateBotControl(double dt) {
    if (botTactic != null &&
        !characterState.isStunned &&
        !characterState.isLanding &&
        characterState.health > 0) {
      botTactic!.execute(this, game.character, dt);
      _botEvadeMechanics();
    }
  }

  void _botEvadeMechanics() {
    final projectiles = game.projectiles
        .where((p) => p.owner != null && position.distanceTo(p.position) < 200 && characterState.dodgeCooldown <= 0)
        .toList();
    if (projectiles.isNotEmpty && characterState.stamina > 15) {
      dodge(Vector2(projectiles.first.direction.x > 0 ? -1.0 : 1.0, 0));
    }
  }

  @override
  void attack() {
    if (equippedWeapon != null) { performWeaponAttack(); return; }
    if (!prepareAttackWithEvent()) return;

    final knifeCount = characterState.comboCount >= 3 ? 3 : 1;
    for (int i = 0; i < knifeCount; i++) {
      final spread = (i - (knifeCount - 1) / 2) * 0.2;
      final base   = facingRight ? Vector2(1, 0) : Vector2(-1, 0);
      final dir    = Vector2(base.x, base.y)..rotate(spread);
      final proj   = Projectile(
        position:   position.clone(),
        direction:  dir,
        damage:     stats.attackDamage * (1.0 + (characterState.comboCount - 1) * 0.15),
        owner:      isPlayer ? this : null,
        enemyOwner: isBot    ? this : null,
        color:      Colors.grey,
        type:       'knife',
      );
      game.add(proj); game.world.add(proj); game.projectiles.add(proj);
    }
    _eventBus.emit(PlaySFXEvent(soundId: 'dagger_shot', volume: 0.8));
  }
}

class ThiefStats extends CharacterStats {
  ThiefStats() : super(
    name: 'Thief', power: 8, magic: 6, dexterity: 16, intelligence: 10,
    weaponName: 'Throwing Knives', attackRange: 8.0, attackDamage: 10,
    color: Colors.green,
  );
}