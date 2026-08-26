## Pure combat math. No nodes, no state, no side effects.
##
## Ported from modules/engine/lib/src/system/combat_system.dart processAttack().
## The critical-hit RNG is lifted out into an explicit parameter so this
## function is deterministic and testable; the roll itself lives in
## roll_critical() below and is never called from calc_damage().
class_name Combat
extends RefCounted

const CRITICAL_MULTIPLIER := 2.0
const CRITICAL_CHANCE := 0.1
const COMBO_MULTIPLIER := 0.2
const BLOCK_MULTIPLIER := 0.3

## Order is significant and matches the Dart source: critical, then combo,
## then block.
static func calc_damage(
	base: float, combo: int, blocking: bool, critical: bool
) -> float:
	var damage := base
	if critical:
		damage *= CRITICAL_MULTIPLIER
	if combo > 0:
		damage *= 1.0 + combo * COMBO_MULTIPLIER
	if blocking:
		damage *= BLOCK_MULTIPLIER
	return damage

## Separated from calc_damage so damage remains deterministic.
static func roll_critical(rng: RandomNumberGenerator) -> bool:
	return rng.randf() < CRITICAL_CHANCE

## Melee reach, from knight.dart:
##   stats.attackRange * 30 * (1 + comboCount * 0.1)
static func melee_reach(attack_range: float, combo: int) -> float:
	return attack_range * 30.0 * (1.0 + combo * 0.1)
