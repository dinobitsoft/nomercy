// lib/components/health_component.dart

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

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
  bool canUse(double amount) => _current >= amount;

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
