// lib/components/health_component.dart

import 'dart:math' as math;

import 'package:flame/components.dart';

/// Health management component (composition over inheritance)
class HealthComponent {
  double _current;
  final double max;
  final List<Function(double)> _onDamageCallbacks = [];
  final List<Function()> _onDeathCallbacks = [];

  HealthComponent({
    required this.max,
    double? current,
  }) : _current = current ?? max;

  double get current => _current;
  double get percent => _current / max;
  bool get isDead => _current <= 0;
  bool get isLow => percent < 0.3;

  /// Take damage
  void takeDamage(double amount) {
    if (isDead) return;

    final oldHealth = _current;
    _current = math.max(0, _current - amount);

    // Trigger callbacks
    for (final callback in _onDamageCallbacks) {
      callback(amount);
    }

    if (isDead && oldHealth > 0) {
      for (final callback in _onDeathCallbacks) {
        callback();
      }
    }
  }

  /// Heal
  void heal(double amount) {
    _current = math.min(max, _current + amount);
  }

  /// Full heal
  void fullHeal() {
    _current = max;
  }

  /// Register callbacks
  void onDamage(Function(double) callback) => _onDamageCallbacks.add(callback);
  void onDeath(Function() callback) => _onDeathCallbacks.add(callback);

  /// Clear callbacks
  void clearCallbacks() {
    _onDamageCallbacks.clear();
    _onDeathCallbacks.clear();
  }
}

// lib/components/stamina_component.dart

/// Stamina management component
class StaminaComponent {
  double _current;
  final double max;
  final double regenRate;
  double _regenDelay = 0;
  bool _isRegenerating = true;

  StaminaComponent({
    required this.max,
    this.regenRate = 15.0,
    double? current,
  }) : _current = current ?? max;

  double get current => _current;
  double get percent => _current / max;
  bool get isDepleted => _current <= 0;
  bool get canUse(double amount) => _current >= amount;

  /// Update stamina (call every frame)
  void update(double dt) {
    if (!_isRegenerating) {
      _regenDelay -= dt;
      if (_regenDelay <= 0) {
        _isRegenerating = true;
      }
      return;
    }

    if (_current < max) {
      _current = math.min(max, _current + regenRate * dt);
    }
  }

  /// Use stamina
  bool use(double amount, {double regenDelay = 0.5}) {
    if (!canUse(amount)) return false;

    _current -= amount;

    // Pause regen temporarily
    if (regenDelay > 0) {
      _isRegenerating = false;
      _regenDelay = regenDelay;
    }

    return true;
  }

  /// Force set stamina
  void set(double value) {
    _current = value.clamp(0, max);
  }
}

// lib/components/animation_component.dart

/// Animation state machine component
class AnimationComponent {
  final Map<String, SpriteAnimation> animations;
  String _currentState;
  SpriteAnimation? _currentAnimation;
  double _stateTime = 0;
  final Map<String, int> _statePriority;

  AnimationComponent({
    required this.animations,
    required String initialState,
    Map<String, int>? statePriority,
  })  : _currentState = initialState,
        _statePriority = statePriority ?? {} {
    _currentAnimation = animations[initialState];
  }

  String get currentState => _currentState;
  SpriteAnimation? get animation => _currentAnimation;
  double get stateTime => _stateTime;

  /// Update animation
  void update(double dt) {
    _stateTime += dt;
    _currentAnimation?.update(dt);
  }

  /// Change animation state
  bool setState(String newState, {bool force = false}) {
    if (newState == _currentState && !force) return false;

    // Check priority (higher priority can interrupt lower)
    if (!force) {
      final currentPriority = _statePriority[_currentState] ?? 0;
      final newPriority = _statePriority[newState] ?? 0;

      if (newPriority < currentPriority) {
        return false; // Lower priority, can't interrupt
      }
    }

    final newAnim = animations[newState];
    if (newAnim == null) return false;

    _currentState = newState;
    _currentAnimation = newAnim;
    _stateTime = 0;
    _currentAnimation?.reset();

    return true;
  }

  /// Check if animation is finished (for non-looping anims)
  bool get isAnimationFinished {
    final anim = _currentAnimation;
    if (anim == null || anim.loop) return false;
    return anim.done();
  }
}

// lib/entities/character/character_entity.dart

/// Refactored character entity using composition


// lib/entities/character/character_factory.dart

/// Factory for creating characters (ensures consistency)
