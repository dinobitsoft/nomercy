import 'package:engine/engine.dart';

class ThiefActionStrategy extends ActionStrategy {
  @override double get jumpPower          => -500;
  @override double get dodgeStickYSign    => 1.0;
  @override bool   get dodgeEdgeDetect    => true;
  @override double get attackDuration     => 0.22;
  @override double get jumpStepTime       => 0.10;
  @override double get landingStepTime    => 0.08;
  @override double get defaultAttackRange => 8.0;
  @override String get defaultWeaponName  => 'Throwing Knives';

  @override
  List<Skill> get skills => [ShadowStrike(), SmokeBomb()];
}