import '../core/event_bus.dart';
import '../core/game_event.dart';

class AchievementSystem {
  final Map<String, bool> _unlocked = {};

  AchievementSystem() {
    // Listen for first kill
    EventBus().on<CharacterKilledEvent>((event) {
      if (!_unlocked['first_blood']!) {
        _unlocked['first_blood'] = true;
        EventBus().emit(AchievementUnlockedEvent(
          achievementId: 'first_blood',
          achievementName: 'First Blood',
          description: 'Defeat your first enemy',
          pointsEarned: 10,
        ));
      }
    });

    // Listen for wave milestones
    EventBus().on<WaveCompletedEvent>((event) {
      if (event.waveNumber == 10 && !_unlocked['survivor']!) {
        // Unlock "Survivor" achievement
      }
    });

    // Listen for perfect clears
    EventBus().on<WaveCompletedEvent>((event) {
      if (event.perfectClear) {
        // Track perfect clears
      }
    });
  }
}