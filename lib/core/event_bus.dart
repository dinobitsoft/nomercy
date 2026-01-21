// lib/core/event_bus.dart

import 'dart:async';
import 'dart:math';

/// Game event types
enum GameEventType {
  // Combat events
  characterAttacked,
  characterDamaged,
  characterKilled,
  projectileFired,
  comboTriggered,

  // Game state events
  gameStarted,
  gamePaused,
  gameResumed,
  gameOver,
  waveStarted,
  waveCompleted,

  // Item events
  itemPickedUp,
  itemDropped,
  weaponEquipped,
  chestOpened,

  // Player events
  playerLevelUp,
  playerRespawned,
  staminaDepleted,
  healthLow,

  // Audio events
  playSFX,
  playMusic,
  stopMusic,

  // UI events
  showNotification,
  updateHUD,
}

/// Base game event
abstract class GameEvent {
  final GameEventType type;
  final DateTime timestamp;

  GameEvent(this.type) : timestamp = DateTime.now();
}

/// Combat events
class CharacterAttackedEvent extends GameEvent {
  final String attackerId;
  final String targetId;
  final double damage;
  final bool isCritical;

  CharacterAttackedEvent({
    required this.attackerId,
    required this.targetId,
    required this.damage,
    this.isCritical = false,
  }) : super(GameEventType.characterAttacked);
}

class CharacterDamagedEvent extends GameEvent {
  final String characterId;
  final double damage;
  final double remainingHealth;

  CharacterDamagedEvent({
    required this.characterId,
    required this.damage,
    required this.remainingHealth,
  }) : super(GameEventType.characterDamaged);
}

class CharacterKilledEvent extends GameEvent {
  final String victimId;
  final String killerId;
  final int bounty;

  CharacterKilledEvent({
    required this.victimId,
    required this.killerId,
    required this.bounty,
  }) : super(GameEventType.characterKilled);
}

/// Item events
class ItemPickedUpEvent extends GameEvent {
  final String characterId;
  final String itemId;
  final String itemType;

  ItemPickedUpEvent({
    required this.characterId,
    required this.itemId,
    required this.itemType,
  }) : super(GameEventType.itemPickedUp);
}

class WeaponEquippedEvent extends GameEvent {
  final String characterId;
  final String weaponId;
  final String weaponName;

  WeaponEquippedEvent({
    required this.characterId,
    required this.weaponId,
    required this.weaponName,
  }) : super(GameEventType.weaponEquipped);
}

/// Wave events
class WaveStartedEvent extends GameEvent {
  final int waveNumber;
  final int enemyCount;

  WaveStartedEvent({
    required this.waveNumber,
    required this.enemyCount,
  }) : super(GameEventType.waveStarted);
}

class WaveCompletedEvent extends GameEvent {
  final int waveNumber;
  final int goldReward;
  final Duration completionTime;

  WaveCompletedEvent({
    required this.waveNumber,
    required this.goldReward,
    required this.completionTime,
  }) : super(GameEventType.waveCompleted);
}

/// Audio events
class PlaySFXEvent extends GameEvent {
  final String soundId;
  final double volume;

  PlaySFXEvent({
    required this.soundId,
    this.volume = 1.0,
  }) : super(GameEventType.playSFX);
}

/// Event Bus - Centralized event management
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final StreamController<GameEvent> _streamController =
  StreamController<GameEvent>.broadcast();

  final Map<GameEventType, List<Function(GameEvent)>> _listeners = {};
  final List<GameEvent> _eventHistory = [];
  final int _maxHistorySize = 100;

  /// Subscribe to specific event type
  void on<T extends GameEvent>(
      GameEventType type,
      Function(T) callback,
      ) {
    if (!_listeners.containsKey(type)) {
      _listeners[type] = [];
    }
    _listeners[type]!.add((event) => callback(event as T));
  }

  /// Subscribe to all events of a specific type using stream
  Stream<T> stream<T extends GameEvent>(GameEventType type) {
    return _streamController.stream
        .where((event) => event.type == type)
        .cast<T>();
  }

  /// Emit an event
  void emit(GameEvent event) {
    // Add to history
    _eventHistory.add(event);
    if (_eventHistory.length > _maxHistorySize) {
      _eventHistory.removeAt(0);
    }

    // Broadcast to stream
    _streamController.add(event);

    // Call registered listeners
    final listeners = _listeners[event.type];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          listener(event);
        } catch (e) {
          print('❌ Error in event listener: $e');
        }
      }
    }
  }

  /// Remove all listeners for a type
  void off(GameEventType type) {
    _listeners.remove(type);
  }

  /// Clear all listeners
  void clearAll() {
    _listeners.clear();
  }

  /// Get event history
  List<GameEvent> getHistory({GameEventType? filterByType}) {
    if (filterByType == null) {
      return List.unmodifiable(_eventHistory);
    }
    return _eventHistory.where((e) => e.type == filterByType).toList();
  }

  /// Dispose of event bus
  void dispose() {
    _streamController.close();
    _listeners.clear();
    _eventHistory.clear();
  }
}

// lib/systems/combat_system.dart (Example usage)

/// Combat system using event bus
class CombatSystem {
  final EventBus _eventBus = EventBus();

  CombatSystem() {
    _setupEventListeners();
  }

  void _setupEventListeners() {
    // Listen for character attacks
    _eventBus.on<CharacterAttackedEvent>(
      GameEventType.characterAttacked,
      _handleAttack,
    );

    // Listen for character deaths
    _eventBus.on<CharacterKilledEvent>(
      GameEventType.characterKilled,
      _handleDeath,
    );
  }

  /// Process attack
  void processAttack({
    required String attackerId,
    required String targetId,
    required double baseDamage,
  }) {
    // Calculate damage with crits
    final isCrit = _rollCritical();
    final finalDamage = isCrit ? baseDamage * 2.0 : baseDamage;

    // Emit attack event
    _eventBus.emit(CharacterAttackedEvent(
      attackerId: attackerId,
      targetId: targetId,
      damage: finalDamage,
      isCritical: isCrit,
    ));

    if (isCrit) {
      print('💥 CRITICAL HIT! ${finalDamage.toInt()} damage');
    }
  }

  void _handleAttack(CharacterAttackedEvent event) {
    print('⚔️ ${event.attackerId} attacked ${event.targetId} '
        'for ${event.damage.toInt()} damage');

    // Play attack sound
    _eventBus.emit(PlaySFXEvent(soundId: 'hit'));
  }

  void _handleDeath(CharacterKilledEvent event) {
    print('💀 ${event.victimId} was killed by ${event.killerId}');
    print('💰 Earned ${event.bounty} gold');

    // Play death sound
    _eventBus.emit(PlaySFXEvent(soundId: 'death'));
  }

  bool _rollCritical() {
    return Random().nextDouble() < 0.1; // 10% crit chance
  }
}