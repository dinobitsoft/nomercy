import 'gamepad.dart';
enum GamepadNavEvent { up, down, left, right, confirm, back, start }

/// Thin façade — all event logic lives in [GamepadManager].
/// Screens subscribe via [GamepadRouteAware] which listens to [events].
class GamepadNavService {
  static final GamepadNavService _instance = GamepadNavService._internal();
  factory GamepadNavService() => _instance;
  GamepadNavService._internal();

  /// Delegates to [GamepadManager.navEvents] — no duplicate stream processing.
  Stream<GamepadNavEvent> get events => GamepadManager().navEvents;
}