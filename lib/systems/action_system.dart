import 'dart:ui';

import '../core/action_events.dart';
import '../core/event_bus.dart';
import '../core/game_event.dart';
import '../game/action_game.dart';

/// Centralized system for handling all character actions
/// Converts action intentions into actual game state changes
class ActionSystem {
  final EventBus _eventBus = EventBus();
  final ActionGame game;

  // Action tracking
  final Map<String, String> _currentActions = {};
  final Map<String, DateTime> _actionStartTimes = {};
  final Map<String, int> _actionCounts = {};

  // Subscriptions
  final List<EventSubscription> _subscriptions = [];

  ActionSystem({required this.game}) {
    _setupEventListeners();
  }

  void _setupEventListeners() {
    // Movement events
    _subscriptions.add(_eventBus.on<CharacterWalkStartedEvent>(_onWalkStarted));
    _subscriptions.add(_eventBus.on<CharacterWalkStoppedEvent>(_onWalkStopped));

    // Jump events
    _subscriptions.add(_eventBus.on<CharacterJumpedEvent>(_onJumped));
    _subscriptions.add(_eventBus.on<CharacterLandedEvent>(_onLanded));
    _subscriptions.add(_eventBus.on<CharacterAirborneEvent>(_onAirborne));

    // Attack events
    _subscriptions.add(_eventBus.on<CharacterAttackStartedEvent>(_onAttackStarted));
    _subscriptions.add(_eventBus.on<CharacterAttackCompletedEvent>(_onAttackCompleted));
    _subscriptions.add(_eventBus.on<CharacterAttackCancelledEvent>(_onAttackCancelled));

    // Defense events
    _subscriptions.add(_eventBus.on<CharacterBlockStartedEvent>(_onBlockStarted));
    _subscriptions.add(_eventBus.on<CharacterBlockStoppedEvent>(_onBlockStopped));
    _subscriptions.add(_eventBus.on<CharacterGuardBrokenEvent>(_onGuardBroken));

    // Dodge events
    _subscriptions.add(_eventBus.on<CharacterDodgeStartedEvent>(_onDodgeStarted));
    _subscriptions.add(_eventBus.on<CharacterDodgeCompletedEvent>(_onDodgeCompleted));

    // State events
    _subscriptions.add(_eventBus.on<CharacterIdleEvent>(_onIdle));
    _subscriptions.add(_eventBus.on<CharacterStunnedEvent>(_onStunned));
    _subscriptions.add(_eventBus.on<CharacterStunRecoveredEvent>(_onStunRecovered));

    // Animation events
    _subscriptions.add(_eventBus.on<CharacterAnimationChangedEvent>(_onAnimationChanged));
    _subscriptions.add(_eventBus.on<CharacterAnimationCompletedEvent>(_onAnimationCompleted));

    print('✅ ActionSystem: Event listeners registered');
  }

  // ==========================================
  // MOVEMENT EVENT HANDLERS
  // ==========================================

  void _onWalkStarted(CharacterWalkStartedEvent event) {
    _currentActions[event.characterId] = 'walking';
    _actionStartTimes[event.characterId] = DateTime.now();

    print('🚶 ${event.characterId} started walking (speed: ${event.speed.toInt()})');

    // Play footstep sound
    _eventBus.emit(PlaySFXEvent(soundId: 'footstep', volume: 0.3));
  }

  void _onWalkStopped(CharacterWalkStoppedEvent event) {
    _currentActions.remove(event.characterId);
    _actionStartTimes.remove(event.characterId);
  }

  // ==========================================
  // JUMP EVENT HANDLERS
  // ==========================================

  void _onJumped(CharacterJumpedEvent event) {
    _currentActions[event.characterId] = 'jumping';
    _incrementActionCount(event.characterId, 'jump');

    print('🦘 ${event.characterId} jumped (power: ${event.jumpPower.toInt()})');

    // Play jump sound
    _eventBus.emit(PlaySFXEvent(
      soundId: event.isDoubleJump ? 'double_jump' : 'jump',
      volume: 0.7,
    ));

    // Show visual effect if double jump
    if (event.isDoubleJump) {
      _eventBus.emit(ShowNotificationEvent(
        message: 'DOUBLE JUMP!',
        color: const Color(0xFF00FFFF),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  void _onLanded(CharacterLandedEvent event) {
    _currentActions[event.characterId] = 'landing';

    // Hard landing feedback
    if (event.isHardLanding) {
      print('💥 ${event.characterId} HARD LANDING! (${event.damage.toInt()} dmg)');

      _eventBus.emit(PlaySFXEvent(soundId: 'hard_land', volume: 1.0));
      _eventBus.emit(ShowNotificationEvent(
        message: 'HARD LANDING!',
        color: const Color(0xFFFF4444),
        duration: const Duration(milliseconds: 1500),
      ));

      // Camera shake for player
      if (event.characterId == game.player.stats.name) {
        // TODO: Implement camera shake
      }
    } else {
      _eventBus.emit(PlaySFXEvent(soundId: 'land', volume: 0.5));
    }
  }

  void _onAirborne(CharacterAirborneEvent event) {
    _currentActions[event.characterId] = 'airborne';
  }

  // ==========================================
  // ATTACK EVENT HANDLERS
  // ==========================================

  void _onAttackStarted(CharacterAttackStartedEvent event) {
    _currentActions[event.characterId] = 'attacking';
    _actionStartTimes[event.characterId] = DateTime.now();
    _incrementActionCount(event.characterId, 'attack');

    print('⚔️  ${event.characterId} started ${event.attackType} attack '
        '${event.comboCount > 1 ? "(COMBO x${event.comboCount})" : ""}');

    // Play attack sound based on type
    final soundId = event.attackType == 'ranged' ? 'whoosh' : 'sword_slash';
    _eventBus.emit(PlaySFXEvent(soundId: soundId, volume: 0.8));

    // Show combo notification
    if (event.comboCount >= 3) {
      _eventBus.emit(ShowNotificationEvent(
        message: '${event.comboCount}x COMBO!',
        color: const Color(0xFFFF8800),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _onAttackCompleted(CharacterAttackCompletedEvent event) {
    final startTime = _actionStartTimes[event.characterId];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      print('⚔️  ${event.characterId} completed attack in ${duration.inMilliseconds}ms '
          '(hit ${event.targetsHit} targets, ${event.totalDamage.toInt()} dmg)');
    }

    _currentActions.remove(event.characterId);
    _actionStartTimes.remove(event.characterId);
  }

  void _onAttackCancelled(CharacterAttackCancelledEvent event) {
    print('❌ ${event.characterId} attack cancelled (${event.reason})');

    _currentActions.remove(event.characterId);
    _actionStartTimes.remove(event.characterId);
  }

  // ==========================================
  // DEFENSE EVENT HANDLERS
  // ==========================================

  void _onBlockStarted(CharacterBlockStartedEvent event) {
    _currentActions[event.characterId] = 'blocking';
    _actionStartTimes[event.characterId] = DateTime.now();

    print('🛡️  ${event.characterId} started blocking');

    _eventBus.emit(PlaySFXEvent(soundId: 'shield_up', volume: 0.6));
  }

  void _onBlockStopped(CharacterBlockStoppedEvent event) {
    print('🛡️  ${event.characterId} stopped blocking (${event.reason}, '
        '${event.duration.toStringAsFixed(1)}s)');

    _currentActions.remove(event.characterId);
    _actionStartTimes.remove(event.characterId);

    if (event.reason == 'stamina_depleted') {
      _eventBus.emit(PlaySFXEvent(soundId: 'stamina_depleted', volume: 0.8));
    }
  }

  void _onGuardBroken(CharacterGuardBrokenEvent event) {
    print('💥 ${event.characterId} GUARD BROKEN!');

    _eventBus.emit(PlaySFXEvent(soundId: 'guard_break', volume: 1.0));
    _eventBus.emit(ShowNotificationEvent(
      message: 'GUARD BROKEN!',
      color: const Color(0xFFFF4444),
      duration: const Duration(seconds: 2),
    ));
  }

  // ==========================================
  // DODGE EVENT HANDLERS
  // ==========================================

  void _onDodgeStarted(CharacterDodgeStartedEvent event) {
    _currentActions[event.characterId] = 'dodging';
    _actionStartTimes[event.characterId] = DateTime.now();
    _incrementActionCount(event.characterId, 'dodge');

    print('💨 ${event.characterId} started dodge roll');

    _eventBus.emit(PlaySFXEvent(soundId: 'dodge', volume: 0.7));
  }

  void _onDodgeCompleted(CharacterDodgeCompletedEvent event) {
    print('💨 ${event.characterId} completed dodge '
        '${event.avoidedDamage ? "(AVOIDED DAMAGE!)" : ""}');

    _currentActions.remove(event.characterId);
    _actionStartTimes.remove(event.characterId);

    if (event.avoidedDamage) {
      _eventBus.emit(ShowNotificationEvent(
        message: 'DODGED!',
        color: const Color(0xFF00FF00),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  // ==========================================
  // STATE EVENT HANDLERS
  // ==========================================

  void _onIdle(CharacterIdleEvent event) {
    _currentActions[event.characterId] = 'idle';
  }

  void _onStunned(CharacterStunnedEvent event) {
    _currentActions[event.characterId] = 'stunned';

    print('⚡ ${event.characterId} stunned for ${event.duration.toStringAsFixed(1)}s '
        '(${event.source})');

    _eventBus.emit(PlaySFXEvent(soundId: 'stun', volume: 0.8));
  }

  void _onStunRecovered(CharacterStunRecoveredEvent event) {
    print('⚡ ${event.characterId} recovered from stun');

    _currentActions.remove(event.characterId);
  }

  // ==========================================
  // ANIMATION EVENT HANDLERS
  // ==========================================

  void _onAnimationChanged(CharacterAnimationChangedEvent event) {
    // Track animation transitions for debugging
    // print('🎬 ${event.characterId}: ${event.previousAnimation} → ${event.newAnimation}');
  }

  void _onAnimationCompleted(CharacterAnimationCompletedEvent event) {
    print('🎬 ${event.characterId} completed ${event.animationName} animation');

    // Trigger follow-up actions based on completed animation
    if (event.animationName == 'attack') {
      // Attack animation finished, character can move again
    } else if (event.animationName == 'landing') {
      // Landing animation finished, character can act again
    }
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  void _incrementActionCount(String characterId, String action) {
    final key = '${characterId}_$action';
    _actionCounts[key] = (_actionCounts[key] ?? 0) + 1;
  }

  String? getCurrentAction(String characterId) {
    return _currentActions[characterId];
  }

  int getActionCount(String characterId, String action) {
    return _actionCounts['${characterId}_$action'] ?? 0;
  }

  bool isPerformingAction(String characterId, String action) {
    return _currentActions[characterId] == action;
  }

  // ==========================================
  // STATISTICS
  // ==========================================

  Map<String, dynamic> getStatistics() {
    final stats = <String, dynamic>{};

    // Count actions by type
    final actionTypes = <String, int>{};
    _actionCounts.forEach((key, count) {
      final actionType = key.split('_').last;
      actionTypes[actionType] = (actionTypes[actionType] ?? 0) + count;
    });

    stats['actionsByType'] = actionTypes;
    stats['activeActions'] = _currentActions.length;
    stats['totalActions'] = _actionCounts.values.fold(0, (a, b) => a + b);

    return stats;
  }

  void printStats() {
    final stats = getStatistics();
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🎮 ACTION SYSTEM STATISTICS');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('Total Actions: ${stats['totalActions']}');
    print('Active Actions: ${stats['activeActions']}');
    print('\nActions by Type:');
    (stats['actionsByType'] as Map).forEach((action, count) {
      print('  $action: $count');
    });
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _currentActions.clear();
    _actionStartTimes.clear();
    _actionCounts.clear();

    print('🗑️  ActionSystem: Disposed');
  }
}