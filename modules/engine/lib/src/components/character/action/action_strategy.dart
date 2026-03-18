abstract class ActionStrategy {
  double get jumpPower;
  double get doubleJumpMultiplier => 0.85;

  // Dodge stick gesture: 1.0 = flick down, -1.0 = flick up
  double get dodgeStickYSign;

  // true = isDodgeJustPressed (edge), false = isDodgePressed (continuous)
  bool get dodgeEdgeDetect;

  double get dodgeStickThreshold => 0.5;
}