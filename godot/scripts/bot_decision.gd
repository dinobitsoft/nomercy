## Pure bot action scoring. No nodes, no state, no side effects.
##
## Ported from the evaluator set in
## modules/engine/lib/src/bot/smart_bot_ai.dart. Each candidate action is
## scored and the highest wins; ties break in the declared order.
##
## The scoring weights ARE the game's feel. Do not retune them here — any
## change belongs in a .tres personality.
class_name BotDecision
extends RefCounted

static func decide(s: WorldSnapshot, p: BotPersonality) -> String:
	var scores := {
		"dodge": _score_dodge(s, p),
		"retreat": _score_retreat(s, p),
		"attack": _score_attack(s, p),
		"block": _score_block(s, p),
		"approach": _score_approach(s, p),
		"idle": 0.01,
	}

	var best := "idle"
	var best_score := 0.0
	for action in scores:
		if scores[action] > best_score:
			best_score = scores[action]
			best = action
	return best

static func _score_dodge(s: WorldSnapshot, p: BotPersonality) -> float:
	if not s.projectile_incoming:
		return 0.0
	if s.stamina < 20.0:
		return 0.0
	# Even a reckless personality dodges projectiles.
	return 0.9 + p.caution * 0.1

static func _score_retreat(s: WorldSnapshot, p: BotPersonality) -> float:
	if s.health_percent * 100.0 >= p.retreat_threshold:
		return 0.0
	# Hard gate below the threshold: retreat must dominate every other
	# action, not merely compete with them as a soft weight.
	return 1.0 + p.caution * 0.2

static func _score_attack(s: WorldSnapshot, p: BotPersonality) -> float:
	if s.distance_to_target >= s.melee_reach:
		return 0.0
	if s.stamina < p.stamina_reserve:
		return 0.0
	return 0.5 + p.aggression * 0.5

static func _score_block(s: WorldSnapshot, p: BotPersonality) -> float:
	if not s.target_is_attacking:
		return 0.0
	if s.distance_to_target > s.melee_reach * 2.0:
		return 0.0
	if s.stamina < 10.0:
		return 0.0
	return 0.4 + p.caution * 0.5

static func _score_approach(s: WorldSnapshot, p: BotPersonality) -> float:
	if s.distance_to_target <= s.melee_reach:
		return 0.0
	# The further past optimal range, the more urgent closing becomes.
	var gap := s.distance_to_target - p.optimal_range
	var urgency: float = clampf(gap / 400.0, 0.0, 1.0)
	return 0.2 + p.aggression * 0.4 + urgency * 0.2
