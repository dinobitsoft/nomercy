import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../components/damage_number_component.dart';
import '../components/notification_component.dart';
import '../core/event_bus.dart';
import '../core/game_event.dart';
import '../game/action_game.dart';
import '../game/game_character.dart';

class UISystem {
  final EventBus _eventBus = EventBus();
  final ActionGame game;

  // Subscriptions
  final List<EventSubscription> _subscriptions = [];

  // Active notifications
  final List<NotificationComponent> _notifications = [];
  final List<DamageNumberComponent> _damageNumbers = [];

  UISystem({required this.game}) {
    _setupEventListeners();
  }

  void _setupEventListeners() {
    // Listen for notifications
    _subscriptions.add(
      _eventBus.on<ShowNotificationEvent>(
        _onShowNotification,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for damage numbers
    _subscriptions.add(
      _eventBus.on<ShowDamageNumberEvent>(
        _onShowDamageNumber,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for HUD updates
    _subscriptions.add(
      _eventBus.on<UpdateHUDEvent>(
        _onUpdateHUD,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for wave events
    _subscriptions.add(
      _eventBus.on<WaveStartedEvent>(
        _onWaveStarted,
        priority: ListenerPriority.normal,
      ),
    );

    _subscriptions.add(
      _eventBus.on<WaveCompletedEvent>(
        _onWaveCompleted,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for combo events
    _subscriptions.add(
      _eventBus.on<ComboTriggeredEvent>(
        _onComboTriggered,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for achievement unlocks
    _subscriptions.add(
      _eventBus.on<AchievementUnlockedEvent>(
        _onAchievementUnlocked,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for character healed
    _subscriptions.add(
      _eventBus.on<CharacterHealedEvent>(
        _onCharacterHealed,
        priority: ListenerPriority.normal,
      ),
    );

    // Listen for health low warning
    _subscriptions.add(
      _eventBus.on<HealthLowEvent>(
        _onHealthLow,
        priority: ListenerPriority.normal,
      ),
    );

    print('✅ UISystem: Event listeners registered');
  }

  // ==========================================
  // EVENT HANDLERS
  // ==========================================

  void _onShowNotification(ShowNotificationEvent event) {
    final notification = NotificationComponent(
      message: event.message,
      color: event.color,
      lifetime: event.duration.inSeconds.toDouble(),
      icon: event.icon,
      position: Vector2(
        game.size.x / 2,
        150 + (_notifications.length * 40),
      ),
    );

    game.camera.viewport.add(notification);
    _notifications.add(notification);

    print('📢 Notification: ${event.message}');
  }

  void _onShowDamageNumber(ShowDamageNumberEvent event) {
    final damageNumber = DamageNumberComponent(
      damage: event.damage,
      isCritical: event.isCritical,
      color: event.color,
      position: event.position.clone(),
    );

    game.world.add(damageNumber);
    _damageNumbers.add(damageNumber);
  }

  void _onUpdateHUD(UpdateHUDEvent event) {
    // HUD component will handle this
    print('🖥️  HUD Update: ${event.element} = ${event.value}');
  }

  void _onWaveStarted(WaveStartedEvent event) {
    String message = '🌊 Wave ${event.waveNumber}';
    Color color = Colors.cyan;

    // Special wave messages
    if (event.waveNumber % 5 == 0) {
      message = '⚠️ BOSS WAVE ${event.waveNumber}!';
      color = Colors.red;
    } else if (event.waveNumber % 10 == 0) {
      message = '🎉 MILESTONE WAVE ${event.waveNumber}!';
      color = Colors.yellowAccent;
    }

    _eventBus.emit(ShowNotificationEvent(
      message: message,
      color: color,
      duration: const Duration(seconds: 3),
    ));
  }

  void _onWaveCompleted(WaveCompletedEvent event) {
    String message = '✅ Wave ${event.waveNumber} Complete!\n+${event.goldReward} Gold';

    if (event.perfectClear) {
      message += '\n🌟 PERFECT CLEAR!';
    }

    _eventBus.emit(ShowNotificationEvent(
      message: message,
      color: Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }

  void _onComboTriggered(ComboTriggeredEvent event) {
    if (event.comboCount >= 3) {
      _eventBus.emit(ShowNotificationEvent(
        message: '${event.comboCount}x COMBO!',
        color: Colors.orange,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _onAchievementUnlocked(AchievementUnlockedEvent event) {
    _eventBus.emit(ShowNotificationEvent(
      message: '🏆 ${event.achievementName}\n${event.description}',
      color: Colors.yellowAccent,
      duration: const Duration(seconds: 5),
    ));
  }

  void _onCharacterHealed(CharacterHealedEvent event) {
    // Show heal number (similar to damage number)
    final character = _findCharacter(event.characterId);
    if (character != null) {
      _eventBus.emit(ShowDamageNumberEvent(
        position: character.position.clone(),
        damage: event.healAmount,
        color: Colors.green,
      ));
    }
  }

  void _onHealthLow(HealthLowEvent event) {
    // Only show warning for player
    if (event.characterId == game.player.stats.name) {
      _eventBus.emit(ShowNotificationEvent(
        message: '⚠️ LOW HEALTH!',
        color: Colors.red,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ==========================================
  // UTILITIES
  // ==========================================

  GameCharacter? _findCharacter(String characterId) {
    if (game.player.stats.name == characterId) {
      return game.player;
    }
    return game.enemies.firstWhere(
          (e) => e.stats.name == characterId,
      orElse: () => null as GameCharacter,
    );
  }

  /// Update UI system (call every frame)
  void update(double dt) {
    // Clean up finished notifications
    _notifications.removeWhere((n) => !n.isMounted);
    _damageNumbers.removeWhere((d) => !d.isMounted);
  }

  // ==========================================
  // CLEANUP
  // ==========================================

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _notifications.clear();
    _damageNumbers.clear();

    print('🗑️  UISystem: Disposed');
  }
}