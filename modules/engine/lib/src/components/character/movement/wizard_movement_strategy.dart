import 'movement_strategy.dart';

class WizardMovementStrategy extends MovementStrategy {
  @override double get walkSpeedMultiplier => 100;
  @override double get runSpeedMultiplier  => 150;
  @override double get runThreshold        => 0.8;
  @override double get attackMoveMultiplier => 0.2;
}