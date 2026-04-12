// modules/engine/lib/src/bot/ai_tactic_provider.dart

import '../components/character/tactic/bot_tactic.dart';

/// Minimal hook that lets the `ai` module supply tactic instances to engine
/// code (GameManager, ActionGame, InfiniteWorldSystem) without creating a
/// circular dependency.
///
/// Engine only stores a single callback.  The full registry logic and the
/// concrete tactic classes live in the `ai` module.
///
/// Call [AiTacticProvider.register] once at startup (from [AiModule.register]).
typedef TacticByName = BotTactic? Function(String name);

class AiTacticProvider {
  AiTacticProvider._();

  static TacticByName? _factory;

  static void register(TacticByName factory) => _factory = factory;

  /// Returns a tactic by personality / class name, or null if not registered.
  static BotTactic? create(String name) => _factory?.call(name);

  /// Returns a tactic for each name in [names], skipping any not registered.
  static List<BotTactic> createAll(List<String> names) =>
      names.map(create).whereType<BotTactic>().toList();
}
