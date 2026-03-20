import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Trader extends GameCharacter {
  final EventBus _eventBus = EventBus();

  @override late final ActionStrategy  actionStrategy  = TraderActionStrategy();
  @override late final MovementStrategy movementStrategy = TraderMovementStrategy();

  Trader({
    required super.position,
    required super.playerType,
    BotTactic? botTactic,
    super.customId,
  }) : super(botTactic: botTactic ?? BalancedTactic(), stats: TraderStats());

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
    if (dist < 180 && game.character.characterState.isAttacking &&
        !characterState.isDodging && characterState.stamina > 25) { startBlock(); }
    else if (characterState.isBlocking &&
        (!game.character.characterState.isAttacking || dist > 180)) { stopBlock(); }
    final projectiles = game.projectiles
        .where((p) => p.owner != null && position.distanceTo(p.position) < 150 && characterState.dodgeCooldown <= 0)
        .toList();
    if (projectiles.isNotEmpty && characterState.stamina > 20) {
      dodge(Vector2(projectiles.first.direction.x > 0 ? -1 : 1, 0));
    }
  }

  @override
  void attack() {
    if (equippedWeapon != null) { performWeaponAttack(); return; }
    if (characterState.isBlocking || characterState.health <= 0) return;
    if (!prepareAttackWithEvent()) return;

    final isPower = characterState.comboCount >= 4;
    final dir     = facingRight ? Vector2(1,0) : Vector2(-1,0);
    final proj    = Projectile(
      position:   position.clone(),
      direction:  dir,
      damage:     stats.attackDamage * (1.0 + (characterState.comboCount-1)*0.18) * (isPower ? 1.5 : 1.0),
      owner:      isPlayer ? this : null,
      enemyOwner: isBot    ? this : null,
      color:      isPower ? Colors.red : Colors.brown,
      type:       'arrow',
    );
    game.add(proj); game.world.add(proj); game.projectiles.add(proj);
    if (!characterState.isAirborne) velocity.x -= facingRight ? 20 : -20;
    _eventBus.emit(PlaySFXEvent(soundId: 'arrow_shot', volume: 0.8));
  }
}

class TraderStats extends CharacterStats {
  TraderStats() : super(
    name: 'Trader', power: 10, magic: 7, dexterity: 12, intelligence: 11,
    weaponName: 'Bow & Arrow', attackRange: 12.0, attackDamage: 12,
    color: Colors.orange,
  );
}