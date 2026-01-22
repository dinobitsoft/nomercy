// lib/core/events/game_event.dart

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:nomercy/item/item.dart';

/// Base class for all game events
abstract class GameEvent {
  final DateTime timestamp;
  final String eventId;

  GameEvent()
      : timestamp = DateTime.now(),
        eventId = _generateEventId();

  static String _generateEventId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
  }

  static int _counter = 0;

  @override
  String toString() => '$runtimeType at $timestamp';
}

// ============================================
// COMBAT EVENTS
// ============================================

/// Character attacked another character
class CharacterAttackedEvent extends GameEvent {
  final String attackerId;
  final String targetId;
  final double damage;
  final bool isCritical;
  final bool isBlocked;
  final String attackType; // 'melee', 'projectile', 'ability'
  final int comboCount;

  CharacterAttackedEvent({
    required this.attackerId,
    required this.targetId,
    required this.damage,
    this.isCritical = false,
    this.isBlocked = false,
    this.attackType = 'melee',
    this.comboCount = 0,
  });

  @override
  String toString() =>
      'Attack: $attackerId → $targetId (${damage.toInt()} dmg, '
          '${isCritical ? "CRIT" : ""}${isBlocked ? "BLOCKED" : ""})';
}

/// Character took damage
class CharacterDamagedEvent extends GameEvent {
  final String characterId;
  final double damage;
  final double remainingHealth;
  final double healthPercent;
  final String damageSource; // 'character', 'environment', 'fall'

  CharacterDamagedEvent({
    required this.characterId,
    required this.damage,
    required this.remainingHealth,
    required this.healthPercent,
    this.damageSource = 'character',
  });

  @override
  String toString() =>
      'Damage: $characterId took ${damage.toInt()} dmg '
          '(${remainingHealth.toInt()} HP remaining)';
}

/// Character died
class CharacterKilledEvent extends GameEvent {
  final String victimId;
  final String? killerId;
  final int bountyGold;
  final Vector2 deathPosition;
  final bool shouldDropLoot;

  CharacterKilledEvent({
    required this.victimId,
    this.killerId,
    required this.bountyGold,
    required this.deathPosition,
    this.shouldDropLoot = true,
  });

  @override
  String toString() =>
      'Death: $victimId killed by ${killerId ?? "environment"} '
          '(+$bountyGold gold)';
}

/// Character healed
class CharacterHealedEvent extends GameEvent {
  final String characterId;
  final double healAmount;
  final double newHealth;
  final String healSource; // 'potion', 'regeneration', 'ability'

  CharacterHealedEvent({
    required this.characterId,
    required this.healAmount,
    required this.newHealth,
    this.healSource = 'potion',
  });
}

/// Combo triggered
class ComboTriggeredEvent extends GameEvent {
  final String characterId;
  final int comboCount;
  final double damageMultiplier;

  ComboTriggeredEvent({
    required this.characterId,
    required this.comboCount,
    required this.damageMultiplier,
  });

  @override
  String toString() => 'Combo: $characterId x$comboCount '
      '(${damageMultiplier.toStringAsFixed(1)}x damage)';
}

/// Projectile fired
class ProjectileFiredEvent extends GameEvent {
  final String shooterId;
  final String projectileType;
  final Vector2 position;
  final Vector2 direction;
  final double damage;

  ProjectileFiredEvent({
    required this.shooterId,
    required this.projectileType,
    required this.position,
    required this.direction,
    required this.damage,
  });
}

/// Projectile hit something
class ProjectileHitEvent extends GameEvent {
  final String projectileType;
  final String? targetId;
  final Vector2 hitPosition;
  final bool hitCharacter;

  ProjectileHitEvent({
    required this.projectileType,
    this.targetId,
    required this.hitPosition,
    required this.hitCharacter,
  });
}

// ============================================
// GAME STATE EVENTS
// ============================================

/// Game started
class GameStartedEvent extends GameEvent {
  final String gameMode;
  final String characterClass;
  final String mapName;

  GameStartedEvent({
    required this.gameMode,
    required this.characterClass,
    required this.mapName,
  });
}

/// Game paused
class GamePausedEvent extends GameEvent {
  final String reason; // 'menu', 'inventory', 'disconnect'

  GamePausedEvent({this.reason = 'menu'});
}

/// Game resumed
class GameResumedEvent extends GameEvent {}

/// Game over
class GameOverEvent extends GameEvent {
  final String reason; // 'death', 'victory', 'timeout'
  final int finalScore;
  final int wavesCompleted;
  final int enemiesKilled;
  final int goldEarned;
  final Duration playTime;

  GameOverEvent({
    required this.reason,
    required this.finalScore,
    required this.wavesCompleted,
    required this.enemiesKilled,
    required this.goldEarned,
    required this.playTime,
  });

  @override
  String toString() => 'Game Over: $reason (Score: $finalScore, '
      'Waves: $wavesCompleted, Kills: $enemiesKilled)';
}

// ============================================
// WAVE EVENTS
// ============================================

/// Wave started
class WaveStartedEvent extends GameEvent {
  final int waveNumber;
  final int enemyCount;
  final List<String> enemyTypes;
  final double difficultyMultiplier;

  WaveStartedEvent({
    required this.waveNumber,
    required this.enemyCount,
    required this.enemyTypes,
    required this.difficultyMultiplier,
  });

  @override
  String toString() => 'Wave $waveNumber started ($enemyCount enemies)';
}

/// Wave completed
class WaveCompletedEvent extends GameEvent {
  final int waveNumber;
  final int goldReward;
  final Duration completionTime;
  final bool perfectClear; // No damage taken

  WaveCompletedEvent({
    required this.waveNumber,
    required this.goldReward,
    required this.completionTime,
    this.perfectClear = false,
  });

  @override
  String toString() => 'Wave $waveNumber complete '
      '(+$goldReward gold, ${completionTime.inSeconds}s'
      '${perfectClear ? ", PERFECT!" : ""})';
}

/// Enemy spawned
class EnemySpawnedEvent extends GameEvent {
  final String enemyId;
  final String enemyType;
  final Vector2 spawnPosition;
  final int waveNumber;

  EnemySpawnedEvent({
    required this.enemyId,
    required this.enemyType,
    required this.spawnPosition,
    required this.waveNumber,
  });
}

// ============================================
// ITEM EVENTS
// ============================================

/// Item picked up
class ItemPickedUpEvent extends GameEvent {
  final String characterId;
  final String itemId;
  final ItemType itemType;
  final String itemName;

  ItemPickedUpEvent({
    required this.characterId,
    required this.itemId,
    required this.itemType,
    required this.itemName,
  });

  @override
  String toString() => 'Pickup: $characterId picked up $itemName';
}

/// Item dropped
class ItemDroppedEvent extends GameEvent {
  final String itemId;
  final String itemType;
  final Vector2 dropPosition;
  final String? droppedBy;

  ItemDroppedEvent({
    required this.itemId,
    required this.itemType,
    required this.dropPosition,
    this.droppedBy,
  });
}

/// Weapon equipped
class WeaponEquippedEvent extends GameEvent {
  final String characterId;
  final String weaponId;
  final String weaponName;
  final double newDamage;
  final double newRange;

  WeaponEquippedEvent({
    required this.characterId,
    required this.weaponId,
    required this.weaponName,
    required this.newDamage,
    required this.newRange,
  });

  @override
  String toString() => 'Equip: $characterId equipped $weaponName '
      '(${newDamage.toInt()} dmg, ${newRange.toInt()} range)';
}

/// Chest opened
class ChestOpenedEvent extends GameEvent {
  final String chestId;
  final String? reward;
  final Vector2 position;

  ChestOpenedEvent({
    required this.chestId,
    this.reward,
    required this.position,
  });
}

// ============================================
// PLAYER EVENTS
// ============================================

/// Player leveled up
class PlayerLevelUpEvent extends GameEvent {
  final int newLevel;
  final int statPointsEarned;

  PlayerLevelUpEvent({
    required this.newLevel,
    required this.statPointsEarned,
  });
}

/// Player respawned
class PlayerRespawnedEvent extends GameEvent {
  final Vector2 spawnPosition;
  final double respawnTime;

  PlayerRespawnedEvent({
    required this.spawnPosition,
    required this.respawnTime,
  });
}

/// Stamina depleted
class StaminaDepletedEvent extends GameEvent {
  final String characterId;

  StaminaDepletedEvent({required this.characterId});
}

/// Health critically low
class HealthLowEvent extends GameEvent {
  final String characterId;
  final double remainingHealth;
  final double healthPercent;

  HealthLowEvent({
    required this.characterId,
    required this.remainingHealth,
    required this.healthPercent,
  });
}

// ============================================
// AUDIO EVENTS
// ============================================

/// Play sound effect
class PlaySFXEvent extends GameEvent {
  final String soundId;
  final double volume;
  final Vector2? position; // For spatial audio

  PlaySFXEvent({
    required this.soundId,
    this.volume = 1.0,
    this.position,
  });
}

/// Play music
class PlayMusicEvent extends GameEvent {
  final String musicId;
  final double volume;
  final bool loop;
  final double fadeInDuration;

  PlayMusicEvent({
    required this.musicId,
    this.volume = 0.6,
    this.loop = true,
    this.fadeInDuration = 1.0,
  });
}

/// Stop music
class StopMusicEvent extends GameEvent {
  final double fadeOutDuration;

  StopMusicEvent({this.fadeOutDuration = 1.0});
}

// ============================================
// UI EVENTS
// ============================================

/// Show notification
class ShowNotificationEvent extends GameEvent {
  final String message;
  final Color color;
  final Duration duration;
  final IconData? icon;

  ShowNotificationEvent({
    required this.message,
    this.color = Colors.white,
    this.duration = const Duration(seconds: 2),
    this.icon,
  });
}

/// Update HUD
class UpdateHUDEvent extends GameEvent {
  final String element; // 'health', 'stamina', 'gold', 'kills'
  final dynamic value;

  UpdateHUDEvent({
    required this.element,
    required this.value,
  });
}

/// Show damage number
class ShowDamageNumberEvent extends GameEvent {
  final Vector2 position;
  final double damage;
  final bool isCritical;
  final Color color;

  ShowDamageNumberEvent({
    required this.position,
    required this.damage,
    this.isCritical = false,
    this.color = Colors.red,
  });
}

// ============================================
// MULTIPLAYER EVENTS
// ============================================

/// Player connected
class PlayerConnectedEvent extends GameEvent {
  final String playerId;
  final String playerName;
  final String characterClass;

  PlayerConnectedEvent({
    required this.playerId,
    required this.playerName,
    required this.characterClass,
  });
}

/// Player disconnected
class PlayerDisconnectedEvent extends GameEvent {
  final String playerId;
  final String reason;

  PlayerDisconnectedEvent({
    required this.playerId,
    required this.reason,
  });
}

// ============================================
// ACHIEVEMENT EVENTS
// ============================================

/// Achievement unlocked
class AchievementUnlockedEvent extends GameEvent {
  final String achievementId;
  final String achievementName;
  final String description;
  final int pointsEarned;

  AchievementUnlockedEvent({
    required this.achievementId,
    required this.achievementName,
    required this.description,
    required this.pointsEarned,
  });

  @override
  String toString() => 'Achievement: $achievementName (+$pointsEarned pts)';
}