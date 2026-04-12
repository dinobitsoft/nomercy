// modules/ai/lib/src/ai_tactic_registry.dart

import 'package:engine/engine.dart';

typedef BotTacticFactory = BotTactic Function();

/// Full tactic registry — lives in the `ai` module.
///
/// Maps personality / character-class names to factory functions.
/// Used internally by [AiModule.register] to wire [AiTacticProvider].
class AiTacticRegistry {
  AiTacticRegistry._();

  static final Map<String, BotTacticFactory> _byPersonality = {};
  static final Map<String, BotTacticFactory> _byClass       = {};

  static void registerForPersonality(String name, BotTacticFactory f) =>
      _byPersonality[name.toLowerCase()] = f;

  static void registerForClass(String characterClass, BotTacticFactory f) =>
      _byClass[characterClass.toLowerCase()] = f;

  static BotTactic? createByPersonality(String name) =>
      _byPersonality[name.toLowerCase()]?.call();

  static BotTactic? createForClass(String characterClass) =>
      _byClass[characterClass.toLowerCase()]?.call();

  /// Used by [AiTacticProvider] as its single callback — tries personality
  /// lookup first, then character-class lookup.
  static BotTactic? create(String name) =>
      createByPersonality(name) ?? createForClass(name);
}
