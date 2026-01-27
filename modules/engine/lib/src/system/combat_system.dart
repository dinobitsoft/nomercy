// lib/system/combat_system.dart

import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flutter/material.dart';

/// Combat system - handles all combat-related logic using events
class CombatSystem {
  final EventBus _eventBus = EventBus();
  final math.Random _random = math.Random();

  // Combat statistics
  int _totalAttacks = 0;
  int _totalCrits = 0;
  int _totalBlocks = 0;
  double _totalDamageDealt = 0;

  // Active combos tracking
  final Map<String, int> _activeCombos = {};
  final Map<String, double> _comboTimers = {};

  CombatSystem() {
    _setupEventListeners();
  }

  /// Setup all event listeners
  void _setupEventListeners() {
    // Listen for attack events
    _eventBus.on<CharacterAttackedEvent>(
      _handleAttack,
      priority: ListenerPriority.high,
    );

    // Listen for damage events
    _eventBus.on<CharacterDamagedEvent>(
      _handleDamage,
      priority: ListenerPriority.normal,
    );

    // Listen for death events
    _eventBus.on<CharacterKilledEvent>(
      _handleDeath,
      priority: ListenerPriority.high,
    );

    // Listen for projectile hits
    _eventBus.on<ProjectileHitEvent>(
      _handleProjectileHit,
      priority: ListenerPriority.normal,
    );

    print('✅ CombatSystem: Event listeners registered');
  }

  // ==========================================
  // ATTACK PROCESSING
  // ==========================================

  void processAttack({
    required GameCharacter attacker,
    required GameCharacter target,
    String attackType = 'melee',
  }) {
    // CRITICAL: Check if target is still valid
    if (target.characterState.health <= 0 || !target.isMounted) {
      return; // Target is dead or removed, abort attack
    }

    // Calculate base damage
    double damage = attacker.stats.attackDamage;

    // Check for critical hit
    final isCritical = _rollCritical(attacker);
    if (isCritical) {
      damage *= BalanceConfig.criticalHitMultiplier;
      _totalCrits++;
    }

    // Apply combo multiplier
    final comboCount = _activeCombos[attacker.stats.name] ?? 0;
    if (comboCount > 0) {
      final comboMultiplier = 1.0 + (comboCount * BalanceConfig.comboDamageMultiplier);
      damage *= comboMultiplier;
    }

    // Check if target is blocking
    final isBlocked = target.characterState.isBlocking && _canBlock(target, attacker);
    if (isBlocked) {
      damage *= 0.3; // 70% damage reduction
      _totalBlocks++;

      // Drain target stamina
      target.characterState.stamina -= GameConfig.blockStaminaDrain;
      if (target.characterState.stamina < 0) {
        target.characterState.stamina = 0;
        target.stopBlock(); // Guard broken
        _eventBus.emit(ShowNotificationEvent(
          message: 'Guard Broken!',
          color: Colors.orange,
        ));
      }
    }

    // Emit attack event
    _eventBus.emit(CharacterAttackedEvent(
      attackerId: attacker.stats.name,
      targetId: target.stats.name,
      damage: damage,
      isCritical: isCritical,
      isBlocked: isBlocked,
      attackType: attackType,
      comboCount: comboCount,
    ));

    // Update combo
    _updateCombo(attacker, hit: true);

    // Apply damage to target
    applyDamage(
      target: target,
      damage: damage,
      source: attacker.stats.name,
    );

    // Update statistics
    _totalAttacks++;
    _totalDamageDealt += damage;

    // Play sound based on result
    if (isCritical) {
      _eventBus.emit(PlaySFXEvent(soundId: 'critical_hit', volume: 1.2));
    } else if (isBlocked) {
      _eventBus.emit(PlaySFXEvent(soundId: 'block', volume: 0.8));
    } else {
      _eventBus.emit(PlaySFXEvent(soundId: 'hit', volume: 1.0));
    }

    // Show damage number
    _eventBus.emit(ShowDamageNumberEvent(
      position: target.position.clone(),
      damage: damage,
      isCritical: isCritical,
      color: isBlocked ? Colors.blue : (isCritical ? Colors.yellow : Colors.red),
    ));
  }

  /// Apply damage to character
  void applyDamage({
    required GameCharacter target,
    required double damage,
    required String source,
  }) {
    final oldHealth = target.characterState.health;
    target.takeDamage(damage);
    final newHealth = target.characterState.health;

    // Emit damage event
    _eventBus.emit(CharacterDamagedEvent(
      characterId: target.stats.name,
      damage: damage,
      remainingHealth: newHealth,
      healthPercent: newHealth / 100.0,
      damageSource: source,
    ));

    // Check for death
    if (newHealth <= 0 && oldHealth > 0) {
      _handleCharacterDeath(target, source);
    }

    // Check for low health warning
    if (newHealth < 30 && oldHealth >= 30) {
      _eventBus.emit(HealthLowEvent(
        characterId: target.stats.name,
        remainingHealth: newHealth,
        healthPercent: newHealth / 100.0,
      ));
    }
  }

  // ==========================================
  // COMBO SYSTEM
  // ==========================================

  /// Update combo counter
  void _updateCombo(GameCharacter character, {required bool hit}) {
    final name = character.stats.name;

    if (hit) {
      // Increase combo
      _activeCombos[name] = (_activeCombos[name] ?? 0) + 1;
      _comboTimers[name] = GameConfig.comboWindow;

      final comboCount = _activeCombos[name]!;

      // Emit combo event at certain thresholds
      if (comboCount >= 3) {
        final multiplier = 1.0 + (comboCount * BalanceConfig.comboDamageMultiplier);
        _eventBus.emit(ComboTriggeredEvent(
          characterId: name,
          comboCount: comboCount,
          damageMultiplier: multiplier,
        ));
      }
    } else {
      // Reset combo
      _activeCombos.remove(name);
      _comboTimers.remove(name);
    }
  }

  /// Update combo timers (call every frame)
  void updateCombos(double dt) {
    final expiredCombos = <String>[];

    _comboTimers.forEach((name, timer) {
      _comboTimers[name] = timer - dt;
      if (_comboTimers[name]! <= 0) {
        expiredCombos.add(name);
      }
    });

    // Remove expired combos
    for (final name in expiredCombos) {
      _activeCombos.remove(name);
      _comboTimers.remove(name);
    }
  }

  /// Get active combo count
  int getComboCount(String characterId) {
    return _activeCombos[characterId] ?? 0;
  }

  // ==========================================
  // COMBAT MECHANICS
  // ==========================================

  /// Roll for critical hit
  bool _rollCritical(GameCharacter attacker) {
    // Base crit chance + intelligence modifier
    final critChance = BalanceConfig.criticalHitChance +
        (attacker.stats.intelligence / 1000);
    return _random.nextDouble() < critChance;
  }

  /// Check if block is successful
  bool _canBlock(GameCharacter blocker, GameCharacter attacker) {
    // Must be facing attacker
    final toAttacker = attacker.position - blocker.position;
    final facingSameDirection =
        (blocker.facingRight && toAttacker.x > 0) ||
            (!blocker.facingRight && toAttacker.x < 0);

    return facingSameDirection && blocker.characterState.stamina >= GameConfig.blockStaminaDrain;
  }

  // ==========================================
  // EVENT HANDLERS
  // ==========================================

  void _handleAttack(CharacterAttackedEvent event) {
    print('⚔️  ${event.attackerId} attacked ${event.targetId}: '
        '${event.damage.toInt()} dmg '
        '${event.isCritical ? "(CRIT!)" : ""}'
        '${event.isBlocked ? "(BLOCKED)" : ""}');
  }

  void _handleDamage(CharacterDamagedEvent event) {
    print('💔 ${event.characterId} took ${event.damage.toInt()} damage '
        '(${event.remainingHealth.toInt()} HP left)');
  }

  void _handleDeath(CharacterKilledEvent event) {
    print('💀 ${event.victimId} was killed by ${event.killerId ?? "environment"}');

    // Play death sound
    _eventBus.emit(PlaySFXEvent(soundId: 'death'));

    // Show death notification //TODO: make it available if special notification mode activated
/*    _eventBus.emit(ShowNotificationEvent(
      message: '${event.victimId} was defeated!',
      color: Colors.red,
      duration: const Duration(seconds: 3),
    ));*/
  }

  void _handleProjectileHit(ProjectileHitEvent event) {
    print('💥 ${event.projectileType} hit ${event.targetId ?? "environment"}');
  }

  void _handleCharacterDeath(GameCharacter victim, String killerId) {
    // Reset combo
    _activeCombos.remove(victim.stats.name);
    _comboTimers.remove(victim.stats.name);

    // Calculate bounty
    final bounty = 20; // Base bounty

    // Emit death event
    _eventBus.emit(CharacterKilledEvent(
      victimId: victim.stats.name,
      killerId: killerId,
      bountyGold: bounty,
      deathPosition: victim.position.clone(),
      shouldDropLoot: true,
    ));
  }

  // ==========================================
  // STATISTICS
  // ==========================================

  /// Get combat statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalAttacks': _totalAttacks,
      'totalCrits': _totalCrits,
      'totalBlocks': _totalBlocks,
      'totalDamage': _totalDamageDealt,
      'critRate': _totalAttacks > 0 ? (_totalCrits / _totalAttacks) : 0.0,
      'blockRate': _totalAttacks > 0 ? (_totalBlocks / _totalAttacks) : 0.0,
      'avgDamage': _totalAttacks > 0 ? (_totalDamageDealt / _totalAttacks) : 0.0,
    };
  }

  /// Print combat statistics
  void printStats() {
    final stats = getStatistics();
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('⚔️  COMBAT STATISTICS');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Total Attacks: ${stats['totalAttacks']}');
    print('Critical Hits: ${stats['totalCrits']} '
        '(${(stats['critRate'] * 100).toStringAsFixed(1)}%)');
    print('Blocks: ${stats['totalBlocks']} '
        '(${(stats['blockRate'] * 100).toStringAsFixed(1)}%)');
    print('Total Damage: ${stats['totalDamage'].toStringAsFixed(0)}');
    print('Average Damage: ${stats['avgDamage'].toStringAsFixed(1)}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  /// Reset statistics
  void resetStats() {
    _totalAttacks = 0;
    _totalCrits = 0;
    _totalBlocks = 0;
    _totalDamageDealt = 0;
    _activeCombos.clear();
    _comboTimers.clear();
  }

  /// Dispose combat system
  void dispose() {
    resetStats();
  }
}