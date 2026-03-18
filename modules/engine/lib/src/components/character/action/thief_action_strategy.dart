import 'package:engine/engine.dart';

class ThiefActionStrategy extends ActionStrategy {
  @override double get jumpPower        => -500;
  @override double get dodgeStickYSign  => 1.0;
  @override bool   get dodgeEdgeDetect  => true;
}