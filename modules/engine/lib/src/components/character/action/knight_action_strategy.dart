import 'package:engine/engine.dart';

class KnightActionStrategy extends ActionStrategy {
  @override double get jumpPower        => -350;
  @override double get dodgeStickYSign  => 1.0;
  @override bool   get dodgeEdgeDetect  => true;
}