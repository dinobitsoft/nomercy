abstract class MovementStrategy {
  double get walkSpeedMultiplier;
  double get runSpeedMultiplier;
  double get runThreshold;
  double get attackMoveMultiplier;

  // Animation step times (seconds per frame)
  double get idleStepTime  => 0.18;
  double get walkStepTime  => 0.12;
  double get runStepTime   => 0.08;

  double resolveSpeed({
    required double baseSpeed,
    required double inputMagnitude,
    required bool isAttackCommitted,
  }) {
    final multiplier = isAttackCommitted ? attackMoveMultiplier : 1.0;
    final isRunning = inputMagnitude > runThreshold;
    return baseSpeed * (isRunning ? runSpeedMultiplier : walkSpeedMultiplier) * multiplier;
  }

  bool isRunning(double inputMagnitude) => inputMagnitude > runThreshold;
}