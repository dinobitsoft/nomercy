class GamepadDevice {
  bool dpadLeft = false;
  bool dpadRight = false;
  bool dpadUp = false;
  bool dpadDown = false;

  static final GamepadDevice _instance = GamepadDevice._internal();

  factory GamepadDevice() => _instance;

  GamepadDevice._internal();

}