abstract class MovementStrategy {
  double get walkSpeedMultiplier;
  double get runSpeedMultiplier;
  double get runThreshold;
  double get attackMoveMultiplier;

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