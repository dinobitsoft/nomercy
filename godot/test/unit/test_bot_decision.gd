extends GutTest

var aggressive: BotPersonality

func before_each():
	aggressive = load("res://resources/personalities/aggressive.tres") as BotPersonality

func _snapshot(
	distance: float, health_pct: float, stamina: float,
	target_attacking: bool = false, projectile_incoming: bool = false
) -> WorldSnapshot:
	var s := WorldSnapshot.new()
	s.distance_to_target = distance
	s.health_percent = health_pct
	s.stamina = stamina
	s.target_is_attacking = target_attacking
	s.projectile_incoming = projectile_incoming
	return s

func test_aggressive_personality_loads_with_dart_values():
	# smart_bot_ai.dart:41-48
	assert_almost_eq(aggressive.aggression, 0.9, 1e-6)
	assert_almost_eq(aggressive.caution, 0.2, 1e-6)
	assert_almost_eq(aggressive.stamina_reserve, 20.0, 1e-6)
	assert_almost_eq(aggressive.optimal_range, 150.0, 1e-6)
	assert_almost_eq(aggressive.retreat_threshold, 20.0, 1e-6)
	assert_almost_eq(aggressive.reaction_time, 0.15, 1e-6)

func test_attacks_when_in_reach_with_stamina():
	var s := _snapshot(50.0, 1.0, 100.0)
	assert_eq(BotDecision.decide(s, aggressive), "attack")

func test_approaches_when_target_is_far():
	var s := _snapshot(600.0, 1.0, 100.0)
	assert_eq(BotDecision.decide(s, aggressive), "approach")

func test_retreats_below_the_retreat_threshold():
	var s := _snapshot(50.0, 0.15, 100.0)
	assert_eq(BotDecision.decide(s, aggressive), "retreat",
		"health 15%% is below the 20%% retreat threshold")

func test_does_not_attack_below_the_stamina_reserve():
	var s := _snapshot(50.0, 1.0, 10.0)
	assert_ne(BotDecision.decide(s, aggressive), "attack",
		"Stamina 10 is under the reserve of 20")

func test_dodges_an_incoming_projectile():
	var s := _snapshot(200.0, 1.0, 100.0, false, true)
	assert_eq(BotDecision.decide(s, aggressive), "dodge")

func test_aggressive_prefers_attacking_over_blocking():
	# aggression 0.9 vs caution 0.2 — it should swing, not turtle.
	var s := _snapshot(50.0, 1.0, 100.0, true)
	assert_eq(BotDecision.decide(s, aggressive), "attack")

func test_a_cautious_personality_blocks_in_the_same_situation():
	var cautious := BotPersonality.new()
	cautious.aggression = 0.3
	cautious.caution = 0.9
	cautious.stamina_reserve = 40.0
	cautious.optimal_range = 350.0
	cautious.retreat_threshold = 30.0
	cautious.reaction_time = 0.10
	var s := _snapshot(50.0, 1.0, 100.0, true)
	assert_eq(BotDecision.decide(s, cautious), "block",
		"Same snapshot, different personality, different action")

func test_idles_when_nothing_applies():
	var s := _snapshot(50.0, 1.0, 5.0)
	assert_eq(BotDecision.decide(s, aggressive), "idle")
