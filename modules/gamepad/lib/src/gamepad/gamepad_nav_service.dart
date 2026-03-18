import 'gamepad_manager.dart';
import 'gamepad_nav_event.dart';

export 'gamepad_nav_event.dart';

/// Thin façade — all input processing lives in [GamepadManager].
/// Importing [GamepadNavService] gives access to [GamepadNavEvent] via re-export.
class GamepadNavService {
  static final GamepadNavService _instance = GamepadNavService._internal();
  factory GamepadNavService() => _instance;
  GamepadNavService._internal();

  /// Delegates to [GamepadManager.navEvents]. No duplicate stream subscription.
  Stream<GamepadNavEvent> get events => GamepadManager().navEvents;
}