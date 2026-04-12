import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Wizard extends GameCharacter {
  final EventBus _eventBus = EventBus();

  @override late final ActionStrategy  actionStrategy  = WizardActionStrategy();
  @override late final MovementStrategy movementStrategy = WizardMovementStrategy();

  Wizard({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
    super.customId,
  }) : super(botTactic: botTactic, stats: WizardStats());

  @override
  void updateBotControl(double dt) {
    if (botTactic != null &&
        !characterState.isStunned &&
        !characterState.isLanding &&
        characterState.health > 0) {
      botTactic!.execute(this, game.character, dt);
      _botMechanics();
    }
  }

  void _botMechanics() {
    final dist = position.distanceTo(game.character.position);
    if (dist < 200 && game.character.characterState.isAttacking &&
        !characterState.isDodging && characterState.stamina > 30) { startBlock(); }
    else if (characterState.isBlocking &&
        (!game.character.characterState.isAttacking || dist > 200)) { stopBlock(); }
    final projectiles = game.projectiles
        .where((p) => p.owner != null && position.distanceTo(p.position) < 100 && characterState.dodgeCooldown <= 0)
        .toList();
    if (projectiles.isNotEmpty && characterState.stamina > 20 && !characterState.isBlocking) {
      dodge(Vector2(projectiles.first.direction.x > 0 ? -1 : 1, 0));
    }
  }

  @override
  void attack() {
    if (equippedWeapon != null) { performWeaponAttack(); return; }
    if (characterState.isBlocking || characterState.health <= 0) return;
    if (!prepareAttackWithEvent()) return;

    final isPower = characterState.comboCount >= 3;
    final origin  = position.clone() + (facingRight ? Vector2(40,0) : Vector2(-40,0));
    final proj    = Projectile(
      position:   origin,
      direction:  facingRight ? Vector2(1,0) : Vector2(-1,0),
      damage:     stats.attackDamage * (1.0 + (characterState.comboCount-1)*0.25),
      owner:      isPlayer ? this : null,
      enemyOwner: isBot    ? this : null,
      color:      isPower ? Colors.blue : Colors.orange,
      type:       'fireball',
    );
    proj.priority = 75;
    game.add(proj); game.world.add(proj); game.projectiles.add(proj);
    if (!characterState.isAirborne) velocity.x -= facingRight ? 30 : -30;
    _eventBus.emit(PlaySFXEvent(soundId: 'fireball_shot', volume: 0.8));
  }
}

class WizardStats extends CharacterStats {
  WizardStats() : super(
    name: 'Wizard', power: 6, magic: 18, dexterity: 7, intelligence: 14,
    weaponName: 'Fireball', attackRange: 10.0, attackDamage: 20,
    color: Colors.purple,
  );
}