import 'movement_strategy.dart';

class ThiefMovementStrategy extends MovementStrategy {
  @override double get walkSpeedMultiplier  => 100;
  @override double get runSpeedMultiplier   => 180;
  @override double get runThreshold         => 0.7;
  @override double get attackMoveMultiplier => 0.5;

  @override double get idleStepTime => 0.16;
  @override double get walkStepTime => 0.09;
  @override double get runStepTime  => 0.06;
}