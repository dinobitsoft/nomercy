import 'package:engine/engine.dart';

class KnightActionStrategy extends ActionStrategy {
  @override double get jumpPower        => -350;
  @override double get dodgeStickYSign  => 1.0;
  @override bool   get dodgeEdgeDetect  => true;

  // Knight swings fast: 0.30 s total, cooldown is 0.5 s — sprite finishes
  // well before the next swing is available.
  @override double get attackDuration   => 0.30;
  @override double get landingStepTime  => 0.10;

  @override double get defaultAttackRange  => 2.0;
  @override String get defaultWeaponName   => 'Sword Slash';
}