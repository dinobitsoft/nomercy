// modules/engine/lib/src/bot/bot_controller_3d.dart

import '../components/character/game_character_3d.dart';
import '../components/character/movement_strategy_3d.dart';
import 'bot_personality_3d.dart';

/// Abstract 3D bot brain interface.
///
/// Engine code ([EnemyCharacter3D]) depends only on this interface.
/// The concrete implementation ([BotAI3D]) lives in the `ai` module and is
/// registered at app-startup via [AiBotRegistry.register].
abstract class BotController3D {
  void update(GameCharacter3D bot, MovementStrategy3D strategy, double dt);
  void onDamageTaken(GameCharacter3D bot, double damage);
}

// ── Factory registry ──────────────────────────────────────────────────────────

typedef BotController3DFactory = BotController3D Function(BotPersonality3D);

/// Decouples [EnemyCharacter3D] from the concrete [BotAI3D] class.
///
/// Call [AiBotRegistry.register] once at app startup (from `AiModule.register`)
/// before any enemy is spawned.
class AiBotRegistry {
  AiBotRegistry._();

  static BotController3DFactory? _factory;

  static void register(BotController3DFactory factory) => _factory = factory;

  static BotController3D create(BotPersonality3D personality) {
    assert(_factory != null,
        'AiBotRegistry: call AiModule.register() before spawning 3D enemies.');
    return _factory!(personality);
  }
}
