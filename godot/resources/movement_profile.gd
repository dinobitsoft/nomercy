## Per-class movement tuning. Ported from
## modules/engine/lib/src/components/character/movement/movement_strategy.dart
class_name MovementProfile
extends Resource

@export var walk_multiplier: float = 100.0
@export var run_multiplier: float = 160.0
@export var run_threshold: float = 0.8
@export var attack_move_multiplier: float = 0.3

## game_character.dart:260 -> baseSpeed: stats.dexterity / 2
static func base_speed(dexterity: float) -> float:
	return dexterity / 2.0

## movement_strategy.dart resolveSpeed()
func resolve_speed(
	dexterity: float, input_magnitude: float, attack_committed: bool
) -> float:
	var multiplier := attack_move_multiplier if attack_committed else 1.0
	var running := input_magnitude > run_threshold
	var class_multiplier := run_multiplier if running else walk_multiplier
	return base_speed(dexterity) * class_multiplier * multiplier
