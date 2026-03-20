import 'movement_strategy.dart';

class TraderMovementStrategy extends MovementStrategy {
  @override double get walkSpeedMultiplier  => 100;
  @override double get runSpeedMultiplier   => 155;
  @override double get runThreshold         => 0.8;
  @override double get attackMoveMultiplier => 0.4;

  @override double get idleStepTime => 0.19;
  @override double get walkStepTime => 0.12;
  @override double get runStepTime  => 0.08;
}