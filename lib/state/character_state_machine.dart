import '../game/game_character.dart';
import 'character_animation_state.dart';

class CharacterStateMachine {
  CharacterAnimState _currentState = CharacterAnimState.idle;
  CharacterAnimState get currentState => _currentState;

  // State priority (higher = more important)
  static const Map<CharacterAnimState, int> _statePriority = {
    CharacterAnimState.dead: 100,
    CharacterAnimState.stunned: 90,
    CharacterAnimState.attacking: 80,
    CharacterAnimState.landing: 70,
    CharacterAnimState.dodging: 60,
    CharacterAnimState.jumping: 50,
    CharacterAnimState.falling: 40,
    CharacterAnimState.blocking: 30,
    CharacterAnimState.walking: 20,
    CharacterAnimState.idle: 10,
  };

  bool requestStateChange(CharacterAnimState newState, {bool force = false}) {
    if (force) {
      _currentState = newState;
      return true;
    }

    final currentPriority = _statePriority[_currentState] ?? 0;
    final newPriority = _statePriority[newState] ?? 0;

    if (newPriority >= currentPriority) {
      _currentState = newState;
      return true;
    }

    return false;
  }

  CharacterAnimState evaluateState(GameCharacter character) {
    // Highest priority first
    if (character.health <= 0) return CharacterAnimState.dead;
    if (character.isStunned) return CharacterAnimState.stunned;
    if (character.isAttacking && character.attackAnimationTimer > 0) {
      return CharacterAnimState.attacking;
    }
    if (character.isLanding && character.landingAnimationTimer > 0) {
      return CharacterAnimState.landing;
    }
    if (character.isDodging) return CharacterAnimState.dodging;
    if (character.isBlocking) return CharacterAnimState.blocking;

    // Ground-based states
    if (character.groundPlatform != null) {
      if (character.velocity.x.abs() > 10) {
        return CharacterAnimState.walking;
      }
      return CharacterAnimState.idle;
    }

    // Airborne states
    if (character.velocity.y < -50) {
      return CharacterAnimState.jumping;
    } else if (character.velocity.y > 50) {
      return CharacterAnimState.falling;
    }

    return CharacterAnimState.idle;
  }
}
