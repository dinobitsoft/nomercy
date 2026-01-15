import '../projectile.dart';
import 'game_character.dart';

abstract class BotTactic {
  String get name;

  void execute(GameCharacter bot, GameCharacter target, double dt);
  bool shouldEvade(GameCharacter bot, List<Projectile> incomingProjectiles);
  void onDamageTaken(GameCharacter bot, double damage);
}
