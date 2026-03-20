import 'package:engine/engine.dart';

class WizardActionStrategy extends ActionStrategy {
  @override double get jumpPower          => -280;
  @override double get dodgeStickYSign    => -1.0;
  @override bool   get dodgeEdgeDetect    => false;
  @override double get attackDuration     => 0.42;
  @override double get jumpStepTime       => 0.18;
  @override double get landingStepTime    => 0.16;
  @override double get defaultAttackRange => 10.0;
  @override String get defaultWeaponName  => 'Fireball';

  @override
  List<Skill> get skills => [MagicBurst(), BlinkTeleport()];
}