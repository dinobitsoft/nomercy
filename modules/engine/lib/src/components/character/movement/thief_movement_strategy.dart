import 'movement_strategy.dart';

class ThiefMovementStrategy extends MovementStrategy {
  @override double get walkSpeedMultiplier => 100;
  @override double get runSpeedMultiplier  => 180;
  @override double get runThreshold        => 0.7;
  @override double get attackMoveMultiplier => 0.5;
}