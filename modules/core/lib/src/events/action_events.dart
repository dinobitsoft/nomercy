import 'package:flame/components.dart';

import 'game_event.dart';

// ============================================
// CHARACTER ACTION EVENTS
// ============================================

/// Base class for all character actions
abstract class CharacterActionEvent extends GameEvent {
  final String characterId;
  final Vector2 position;

  CharacterActionEvent({
    required this.characterId,
    required this.position,
  });
}

// ============================================
// MOVEMENT EVENTS
// ============================================

/// Character started walking
class CharacterWalkStartedEvent extends CharacterActionEvent {
  final Vector2 direction;
  final double speed;

  CharacterWalkStartedEvent({
    required super.characterId,
    required super.position,
    required this.direction,
    required this.speed,
  });

  @override
  String toString() => 'Walk: $characterId started walking (speed: ${speed.toInt()})';
}

/// Character stopped walking
class CharacterWalkStoppedEvent extends CharacterActionEvent {
  CharacterWalkStoppedEvent({
    required super.characterId,
    required super.position,
  });

  @override
  String toString() => 'Walk: $characterId stopped walking';
}

/// Character started running (faster walk)
class CharacterRunStartedEvent extends CharacterActionEvent {
  final Vector2 direction;
  final double speed;

  CharacterRunStartedEvent({
    required super.characterId,
    required super.position,
    required this.direction,
    required this.speed,
  });
}

// ============================================
// JUMP EVENTS
// ============================================

/// Character jumped
class CharacterJumpedEvent extends CharacterActionEvent {
  final double jumpPower;
  final double staminaCost;
  final bool isDoubleJump;

  CharacterJumpedEvent({
    required super.characterId,
    required super.position,
    required this.jumpPower,
    required this.staminaCost,
    this.isDoubleJump = false,
  });

  @override
  String toString() => 'Jump: $characterId jumped '
      '(power: ${jumpPower.toInt()}${isDoubleJump ? ", DOUBLE JUMP" : ""})';
}

/// Character landed on ground
class CharacterLandedEvent extends CharacterActionEvent {
  final double fallSpeed;
  final bool isHardLanding;
  final double damage;

  CharacterLandedEvent({
    required super.characterId,
    required super.position,
    required this.fallSpeed,
    required this.isHardLanding,
    this.damage = 0,
  });

  @override
  String toString() => 'Land: $characterId landed '
      '${isHardLanding ? "(HARD LANDING, ${damage.toInt()} dmg)" : ""}';
}

/// Character became airborne
class CharacterAirborneEvent extends CharacterActionEvent {
  final Vector2 velocity;

  CharacterAirborneEvent({
    required super.characterId,
    required super.position,
    required this.velocity,
  });
}

// ============================================
// ATTACK EVENTS
// ============================================

/// Character started attack
class CharacterAttackStartedEvent extends CharacterActionEvent {
  final String attackType; // 'melee', 'ranged', 'special'
  final int comboCount;
  final double staminaCost;

  CharacterAttackStartedEvent({
    required super.characterId,
    required super.position,
    required this.attackType,
    required this.comboCount,
    required this.staminaCost,
  });

  @override
  String toString() => 'Attack: $characterId started $attackType attack '
      '${comboCount > 1 ? "(COMBO x$comboCount)" : ""}';
}

/// Character completed attack
class CharacterAttackCompletedEvent extends CharacterActionEvent {
  final String attackType;
  final int targetsHit;
  final double totalDamage;

  CharacterAttackCompletedEvent({
    required super.characterId,
    required super.position,
    required this.attackType,
    required this.targetsHit,
    required this.totalDamage,
  });

  @override
  String toString() => 'Attack: $characterId completed attack '
      '(hit $targetsHit targets, ${totalDamage.toInt()} total dmg)';
}

/// Character cancelled attack
class CharacterAttackCancelledEvent extends CharacterActionEvent {
  final String reason; // 'interrupted', 'stunned', 'dodged'

  CharacterAttackCancelledEvent({
    required super.characterId,
    required super.position,
    required this.reason,
  });
}

// ============================================
// DEFENSE EVENTS
// ============================================

/// Character started blocking
class CharacterBlockStartedEvent extends CharacterActionEvent {
  final double staminaPerSecond;

  CharacterBlockStartedEvent({
    required super.characterId,
    required super.position,
    required this.staminaPerSecond,
  });

  @override
  String toString() => 'Block: $characterId started blocking';
}

/// Character stopped blocking
class CharacterBlockStoppedEvent extends CharacterActionEvent {
  final String reason; // 'manual', 'stamina_depleted', 'interrupted'
  final double duration;

  CharacterBlockStoppedEvent({
    required super.characterId,
    required super.position,
    required this.reason,
    required this.duration,
  });

  @override
  String toString() => 'Block: $characterId stopped blocking ($reason)';
}

/// Character's guard was broken
class CharacterGuardBrokenEvent extends CharacterActionEvent {
  final double stunDuration;

  CharacterGuardBrokenEvent({
    required super.characterId,
    required super.position,
    required this.stunDuration,
  });

  @override
  String toString() => 'Block: $characterId GUARD BROKEN!';
}

// ============================================
// DODGE EVENTS
// ============================================

/// Character started dodge roll
class CharacterDodgeStartedEvent extends CharacterActionEvent {
  final Vector2 dodgeDirection;
  final double duration;
  final double staminaCost;

  CharacterDodgeStartedEvent({
    required super.characterId,
    required super.position,
    required this.dodgeDirection,
    required this.duration,
    required this.staminaCost,
  });

  @override
  String toString() => 'Dodge: $characterId started dodge roll';
}

/// Character completed dodge roll
class CharacterDodgeCompletedEvent extends CharacterActionEvent {
  final bool avoidedDamage;

  CharacterDodgeCompletedEvent({
    required super.characterId,
    required super.position,
    required this.avoidedDamage,
  });

  @override
  String toString() => 'Dodge: $characterId completed dodge '
      '${avoidedDamage ? "(AVOIDED DAMAGE!)" : ""}';
}

// ============================================
// STATE EVENTS
// ============================================

/// Character became idle
class CharacterIdleEvent extends CharacterActionEvent {
  CharacterIdleEvent({
    required super.characterId,
    required super.position,
  });

  @override
  String toString() => 'State: $characterId is idle';
}

/// Character was stunned
class CharacterStunnedEvent extends CharacterActionEvent {
  final double duration;
  final String source; // 'hard_landing', 'heavy_attack', 'guard_break'

  CharacterStunnedEvent({
    required super.characterId,
    required super.position,
    required this.duration,
    required this.source,
  });

  @override
  String toString() => 'Stun: $characterId stunned for ${duration.toStringAsFixed(1)}s ($source)';
}

/// Character recovered from stun
class CharacterStunRecoveredEvent extends CharacterActionEvent {
  CharacterStunRecoveredEvent({
    required super.characterId,
    required super.position,
  });

  @override
  String toString() => 'Stun: $characterId recovered from stun';
}

/// Character turned around (changed facing direction)
class CharacterTurnedEvent extends CharacterActionEvent {
  final bool nowFacingRight;

  CharacterTurnedEvent({
    required super.characterId,
    required super.position,
    required this.nowFacingRight,
  });
}

// ============================================
// STAMINA EVENTS
// ============================================

/// Character's stamina depleted
class CharacterStaminaDepletedEvent extends CharacterActionEvent {
  final String lastAction;

  CharacterStaminaDepletedEvent({
    required super.characterId,
    required super.position,
    required this.lastAction,
  });

  @override
  String toString() => 'Stamina: $characterId depleted stamina (was $lastAction)';
}

/// Character's stamina regenerated
class CharacterStaminaRegenEvent extends CharacterActionEvent {
  final double amount;
  final double currentStamina;
  final double maxStamina;

  CharacterStaminaRegenEvent({
    required super.characterId,
    required super.position,
    required this.amount,
    required this.currentStamina,
    required this.maxStamina,
  });
}

// ============================================
// ANIMATION EVENTS
// ============================================

/// Character's animation changed
class CharacterAnimationChangedEvent extends CharacterActionEvent {
  final String previousAnimation;
  final String newAnimation;
  final bool isLooping;

  CharacterAnimationChangedEvent({
    required super.characterId,
    required super.position,
    required this.previousAnimation,
    required this.newAnimation,
    required this.isLooping,
  });

  @override
  String toString() => 'Animation: $characterId $previousAnimation → $newAnimation';
}

/// Character's animation completed (for non-looping animations)
class CharacterAnimationCompletedEvent extends CharacterActionEvent {
  final String animationName;

  CharacterAnimationCompletedEvent({
    required super.characterId,
    required super.position,
    required this.animationName,
  });

  @override
  String toString() => 'Animation: $characterId completed $animationName';
}

// ============================================
// COLLISION EVENTS
// ============================================

/// Character collided with platform
class CharacterPlatformCollisionEvent extends CharacterActionEvent {
  final String platformType;
  final Vector2 collisionNormal;

  CharacterPlatformCollisionEvent({
    required String characterId,
    required Vector2 position,
    required this.platformType,
    required this.collisionNormal,
  }) : super(characterId: characterId, position: position);
}

/// Character collided with another character
class CharacterCharacterCollisionEvent extends CharacterActionEvent {
  final String otherCharacterId;
  final Vector2 collisionPoint;

  CharacterCharacterCollisionEvent({
    required String characterId,
    required Vector2 position,
    required this.otherCharacterId,
    required this.collisionPoint,
  }) : super(characterId: characterId, position: position);
}

// ============================================
// SPECIAL ACTION EVENTS
// ============================================

/// Character used special ability
class CharacterSpecialAbilityUsedEvent extends CharacterActionEvent {
  final String abilityName;
  final double staminaCost;
  final double cooldown;

  CharacterSpecialAbilityUsedEvent({
    required super.characterId,
    required super.position,
    required this.abilityName,
    required this.staminaCost,
    required this.cooldown,
  });

  @override
  String toString() => 'Special: $characterId used $abilityName';
}

/// Character performed a taunt/emote
class CharacterTauntEvent extends CharacterActionEvent {
  final String tauntType;

  CharacterTauntEvent({
    required super.characterId,
    required super.position,
    required this.tauntType,
  });
}

// ============================================
// COMBO EVENTS (Extended from combat_system)
// ============================================

/// Character started a combo chain
class CharacterComboStartedEvent extends CharacterActionEvent {
  CharacterComboStartedEvent({
    required super.characterId,
    required super.position,
  });
}

/// Character's combo was broken
class CharacterComboBrokenEvent extends CharacterActionEvent {
  final int maxComboReached;
  final String reason; // 'timeout', 'missed', 'interrupted'

  CharacterComboBrokenEvent({
    required super.characterId,
    required super.position,
    required this.maxComboReached,
    required this.reason,
  });

  @override
  String toString() => 'Combo: $characterId combo broken at x$maxComboReached ($reason)';
}