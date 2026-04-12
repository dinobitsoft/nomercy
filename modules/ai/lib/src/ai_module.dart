// modules/ai/lib/src/ai_module.dart

import 'package:engine/engine.dart';

import 'ai_tactic_registry.dart';
import 'bot/bot_ai_3d.dart';
import 'tactic/aggressive_tactic.dart';
import 'tactic/balanced_tactic.dart';
import 'tactic/berserker_tactic.dart';
import 'tactic/coward_tactic.dart';
import 'tactic/defensive_tactic.dart';
import 'tactic/sniper_tactic.dart';
import 'tactic/tactical_tactic.dart';

/// Call [AiModule.register] once at app startup (before the first game screen
/// is loaded) to wire all concrete AI implementations into the engine registries.
class AiModule {
  AiModule._();

  static void register() {
    // ── 3D bot factory ───────────────────────────────────────────────────────
    AiBotRegistry.register((personality) => BotAI3D(personality));

    // ── 2D tactic factories (personality name) ───────────────────────────────
    AiTacticRegistry.registerForPersonality('aggressive', AggressiveTactic.new);
    AiTacticRegistry.registerForPersonality('balanced',   BalancedTactic.new);
    AiTacticRegistry.registerForPersonality('defensive',  DefensiveTactic.new);
    AiTacticRegistry.registerForPersonality('tactical',   TacticalTactic.new);
    AiTacticRegistry.registerForPersonality('berserker',  BerserkerTactic.new);
    AiTacticRegistry.registerForPersonality('sniper',     SniperTactic.new);
    AiTacticRegistry.registerForPersonality('coward',     CowardTactic.new);

    // ── 2D tactic factories (character class name) ───────────────────────────
    AiTacticRegistry.registerForClass('knight', AggressiveTactic.new);
    AiTacticRegistry.registerForClass('thief',  BalancedTactic.new);
    AiTacticRegistry.registerForClass('wizard', DefensiveTactic.new);
    AiTacticRegistry.registerForClass('trader', BalancedTactic.new);

    // ── Wire the engine's thin provider to this registry ─────────────────────
    AiTacticProvider.register(AiTacticRegistry.create);
  }
}
