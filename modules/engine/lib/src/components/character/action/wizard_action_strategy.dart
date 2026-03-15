import 'package:engine/engine.dart';

class WizardActionStrategy extends ActionStrategy {
  @override double get jumpPower        => -280;
  @override double get dodgeStickYSign  => -1.0;
  @override bool   get dodgeEdgeDetect  => false;
}