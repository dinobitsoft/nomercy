// lib/state/character_state_machine.dart - ENHANCED VERSION

import '../game/game_character.dart';
import 'character_animation_state.dart';

/// Enhanced state machine with proper transition rules and timing
class CharacterStateMachine {
  CharacterAnimState _currentState = CharacterAnimState.idle;
  CharacterAnimState _previousState = CharacterAnimState.idle;
  double _stateTimer = 0.0;

  // Minimum time in certain states before allowing transitions
  final Map<CharacterAnimState, double> _minimumStateDuration = {
    CharacterAnimState.attacking: 0.3,  // Attack must complete
    CharacterAnimState.landing: 0.15,   // Landing recovery
    CharacterAnimState.dodging: 0.3,    // Dodge roll
  };

  // State transition rules: from -> list of allowed target states
  final Map<CharacterAnimState, Set<CharacterAnimState>> _allowedTransitions = {
    CharacterAnimState.idle: {
      CharacterAnimState.walking,
      CharacterAnimState.jumping,
      CharacterAnimState.attacking,
      CharacterAnimState.blocking,
      CharacterAnimState.dodging,
      CharacterAnimState.stunned,
      CharacterAnimState.dead,
    },
    CharacterAnimState.walking: {
      CharacterAnimState.idle,
      CharacterAnimState.jumping,
      CharacterAnimState.attacking,
      CharacterAnimState.blocking,
      CharacterAnimState.dodging,
      CharacterAnimState.falling,
      CharacterAnimState.stunned,
      CharacterAnimState.dead,
    },
    CharacterAnimState.jumping: {
      CharacterAnimState.falling,
      CharacterAnimState.attacking,
      CharacterAnimState.landing,
      CharacterAnimState.stunned,
      CharacterAnimState.dead,
    },
    CharacterAnimState.falling: {
      CharacterAnimState.landing,
      CharacterAnimState.attacking,
      CharacterAnimState.stunned,
      CharacterAnimState.dead,
    },
    CharacterAnimState.landing: {
      CharacterAnimState.idle,
      CharacterAnimState.walking,
      CharacterAnimState.attacking,
      CharacterAnimState.stunned,
      CharacterAnimState.dead,
    },
    CharacterAnimState.attacking: {
      CharacterAnimState.idle,
      CharacterAnimState.walking,
      CharacterAnimState.jumping,
      CharacterAnimState.falling,
      CharacterAnimState.landing,
      CharacterAnimState.stunned,
      CharacterAnimState.dead,
    },
    CharacterAnimState.blocking: {
      CharacterAnimState.idle,
      CharacterAnimState.walking,
      CharacterAnimState.stunned,
      CharacterAnimState.dead,
    },
    CharacterAnimState.dodging: {
      CharacterAnimState.idle,
      CharacterAnimState.walking,
      CharacterAnimState.falling,
      CharacterAnimState.stunned,
      CharacterAnimState.dead,
    },
    CharacterAnimState.stunned: {
      CharacterAnimState.idle,
      CharacterAnimState.falling,
      CharacterAnimState.dead,
    },
    CharacterAnimState.dead: {}, // Terminal state
  };

  CharacterAnimState get currentState => _currentState;
  CharacterAnimState get previousState => _previousState;
  double get stateTimer => _stateTimer;

  /// Update state timer (call every frame)
  void update(double dt) {
    _stateTimer += dt;
  }

  /// Request state change with validation
  bool requestStateChange(CharacterAnimState newState, {bool force = false}) {
    // Already in this state
    if (newState == _currentState && !force) {
      return false;
    }

    // Dead is terminal
    if (_currentState == CharacterAnimState.dead && !force) {
      return false;
    }

    // Force always succeeds
    if (force) {
      _changeState(newState);
      return true;
    }

    // Check minimum duration requirement
    final minDuration = _minimumStateDuration[_currentState];
    if (minDuration != null && _stateTimer < minDuration) {
      return false; // Can't interrupt yet
    }

    // Check if transition is allowed
    final allowedTargets = _allowedTransitions[_currentState] ?? {};
    if (!allowedTargets.contains(newState)) {
      return false; // Transition not allowed
    }

    // Perform state change
    _changeState(newState);
    return true;
  }

  /// Internal state change
  void _changeState(CharacterAnimState newState) {
    _previousState = _currentState;
    _currentState = newState;
    _stateTimer = 0.0;
  }

  /// Evaluate desired state based on character conditions
  CharacterAnimState evaluateState(GameCharacter character) {
    // Highest priority first (unchangeable states)
    if (character.health <= 0) {
      return CharacterAnimState.dead;
    }

    if (character.isStunned) {
      return CharacterAnimState.stunned;
    }

    // High priority (active actions with timers)
    // Attack animation must complete unless interrupted by stun/death
    if (character.isAttacking && character.attackAnimationTimer > 0.05) {
      return CharacterAnimState.attacking;
    }

    // Dodge animation must complete
    if (character.isDodging && character.dodgeDuration > 0.05) {
      return CharacterAnimState.dodging;
    }

    // Landing animation priority (but can be interrupted by actions)
    if (character.isLanding && character.landingAnimationTimer > 0.05) {
      return CharacterAnimState.landing;
    }

    // Blocking (can be toggled)
    if (character.isBlocking) {
      return CharacterAnimState.blocking;
    }

    // Airborne states - check BEFORE grounded states
    // This prevents "stuck on ground" issues during takeoff
    if (character.groundPlatform == null || character.velocity.y < -100) {
      // Strong upward velocity = jumping
      if (character.velocity.y < -50) {
        return CharacterAnimState.jumping;
      }
      // Falling
      else if (character.velocity.y > 50) {
        return CharacterAnimState.falling;
      }
      // Minimal vertical velocity - maintain current airborne state
      else if (_currentState == CharacterAnimState.jumping ||
          _currentState == CharacterAnimState.falling) {
        return _currentState;
      }
      return CharacterAnimState.falling; // Default airborne
    }

    // Grounded states - only if truly on ground
    if (character.groundPlatform != null && character.velocity.y >= -10) {
      // Walking - significant horizontal movement
      if (character.velocity.x.abs() > 15) {
        return CharacterAnimState.walking;
      }
      // Idle - no significant movement
      return CharacterAnimState.idle;
    }

    // Fallback
    return CharacterAnimState.idle;
  }

  /// Force reset to idle
  void reset() {
    _previousState = _currentState;
    _currentState = CharacterAnimState.idle;
    _stateTimer = 0.0;
  }

  /// Check if state can be interrupted
  bool canInterrupt() {
    final minDuration = _minimumStateDuration[_currentState];
    return minDuration == null || _stateTimer >= minDuration;
  }

  /// Check if specific transition is allowed
  bool canTransitionTo(CharacterAnimState target) {
    if (_currentState == CharacterAnimState.dead) return false;
    if (target == _currentState) return false;

    final allowedTargets = _allowedTransitions[_currentState] ?? {};
    return allowedTargets.contains(target);
  }
}