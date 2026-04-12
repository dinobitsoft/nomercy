import 'package:engine/engine.dart';

abstract class BotTactic {
  String get name;

  /// True for tactics that should never be replaced by a wave upgrade.
  /// Override to `true` in berserker-class tactics.
  bool get isUnupgradable => false;

  void execute(GameCharacter bot, GameCharacter target, double dt);
  bool shouldEvade(GameCharacter bot, List<Projectile> incomingProjectiles);
  void onDamageTaken(GameCharacter bot, double damage);
}
