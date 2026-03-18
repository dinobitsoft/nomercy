import 'package:engine/engine.dart';

class TraderActionStrategy extends ActionStrategy {
  @override double get jumpPower        => -300;
  @override double get dodgeStickYSign  => -1.0;
  @override bool   get dodgeEdgeDetect  => false;
}