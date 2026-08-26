## Pure stamina math. No nodes, no state.
##
## Ported from modules/engine/lib/src/components/character/game_character.dart
## (regen line 529, block drain line 536, attack gate lines 566-567) and
## GameConfig in modules/core/lib/src/config/game_config.dart.
class_name Stamina
extends RefCounted

const REGEN_PER_SECOND := 15.0
const BLOCK_DRAIN_PER_SECOND := 15.0

const ATTACK_MIN := 15.0
const ATTACK_COST_GROUND := 15.0
const ATTACK_COST_AIR := 20.0
const ATTACK_COOLDOWN_GROUND := 0.5
const ATTACK_COOLDOWN_AIR := 1.0

const BLOCK_MIN := 10.0
const JUMP_COST := 20.0
const DODGE_COST := 20.0

static func regen(current: float, maximum: float, delta: float) -> float:
	return minf(maximum, current + REGEN_PER_SECOND * delta)

static func block_drain(current: float, delta: float) -> float:
	return maxf(0.0, current - BLOCK_DRAIN_PER_SECOND * delta)

static func can_attack(current: float) -> bool:
	return current >= ATTACK_MIN

static func attack_cost(airborne: bool) -> float:
	return ATTACK_COST_AIR if airborne else ATTACK_COST_GROUND

static func attack_cooldown(airborne: bool) -> float:
	return ATTACK_COOLDOWN_AIR if airborne else ATTACK_COOLDOWN_GROUND

static func can_block(current: float) -> bool:
	return current >= BLOCK_MIN

static func can_jump(current: float) -> bool:
	return current >= JUMP_COST

static func can_dodge(current: float) -> bool:
	return current >= DODGE_COST
