import 'movement_strategy.dart';

class KnightMovementStrategy extends MovementStrategy {
  @override double get walkSpeedMultiplier  => 100;
  @override double get runSpeedMultiplier   => 160;
  @override double get runThreshold         => 0.8;
  @override double get attackMoveMultiplier => 0.3;

  @override double get idleStepTime => 0.20;
  @override double get walkStepTime => 0.13;
  @override double get runStepTime  => 0.09;
}