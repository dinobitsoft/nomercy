## Bot AI personality parameters. Ported from the personality switch in
## modules/engine/lib/src/bot/smart_bot_ai.dart (lines 41-88).
##
## The seven Dart tactic classes are one algorithm parameterised seven ways;
## in Godot they are seven .tres files against one bot_decision.gd.
class_name BotPersonality
extends Resource

@export var personality_name: String = ""
@export var aggression: float = 0.6
@export var caution: float = 0.5
@export var stamina_reserve: float = 25.0
@export var optimal_range: float = 250.0
@export var retreat_threshold: float = 25.0
@export var reaction_time: float = 0.15
