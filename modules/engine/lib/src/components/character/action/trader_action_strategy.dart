import 'package:engine/engine.dart';

class TraderActionStrategy extends ActionStrategy {
  @override double get jumpPower        => -300;
  @override double get dodgeStickYSign  => -1.0;
  @override bool   get dodgeEdgeDetect  => false;

  // Trader draws and releases: 3-frame sequence over 0.36 s.
  @override double get attackDuration   => 0.36;
  @override double get landingStepTime  => 0.13;

  @override double get defaultAttackRange  => 12.0;
  @override String get defaultWeaponName   => 'Bow & Arrow';
}