extends GutTest

const CHARACTER := preload("res://scenes/character/character.tscn")
const PLATFORM := preload("res://scenes/platform/platform.tscn")

var attacker: Character
var target: Character

func before_each():
	var floor_node = PLATFORM.instantiate()
	floor_node.position = Vector2(0, 500)
	floor_node.size = Vector2(2000, 80)
	add_child_autofree(floor_node)

	attacker = CHARACTER.instantiate()
	attacker.position = Vector2(400, 260)
	attacker.is_enemy = false
	add_child_autofree(attacker)

	target = CHARACTER.instantiate()
	target.position = Vector2(440, 260)  # 40px away, inside the 60px reach
	target.is_enemy = true
	add_child_autofree(target)

	await wait_seconds(1.5)  # let both land

func test_attack_within_reach_damages_target():
	attacker.facing_right = true
	var before := target.health
	var hits := attacker.perform_melee_attack()
	await wait_frames(2)
	assert_eq(hits, 1, "Target at 40px should be within the 60px reach")
	assert_almost_eq(target.health, before - 15.0, 0.01)

func test_attack_out_of_reach_misses():
	target.position = Vector2(900, 260)  # far beyond reach
	await wait_frames(2)
	attacker.facing_right = true
	var before := target.health
	var hits := attacker.perform_melee_attack()
	await wait_frames(2)
	assert_eq(hits, 0)
	assert_almost_eq(target.health, before, 0.01)

func test_attack_spends_fifteen_stamina_on_the_ground():
	var before := attacker.stamina
	attacker.perform_melee_attack()
	assert_almost_eq(attacker.stamina, before - 15.0, 0.01)

func test_attack_is_refused_below_fifteen_stamina():
	attacker.stamina = 10.0
	assert_eq(attacker.perform_melee_attack(), 0,
		"Attack must be refused below 15 stamina")

func test_landing_a_hit_increments_the_combo():
	attacker.facing_right = true
	assert_eq(attacker.combo, 0)
	attacker.perform_melee_attack()
	await wait_frames(2)
	assert_eq(attacker.combo, 1)

func test_combo_increases_damage_on_the_next_hit():
	attacker.facing_right = true
	attacker.perform_melee_attack()
	await wait_frames(2)
	# Clear the cooldown so we can swing again immediately.
	attacker._attack_cooldown = 0.0
	var before := target.health
	attacker.perform_melee_attack()
	await wait_frames(2)
	# combo is 1 going into the second swing: 15 * 1.2 = 18.0
	assert_almost_eq(target.health, before - 18.0, 0.01)

func test_blocking_target_takes_thirty_percent():
	attacker.facing_right = true
	target.start_block()
	var before := target.health
	attacker.perform_melee_attack()
	await wait_frames(2)
	assert_almost_eq(target.health, before - 4.5, 0.01)

func test_attack_respects_cooldown():
	attacker.perform_melee_attack()
	await wait_frames(2)
	assert_eq(attacker.perform_melee_attack(), 0,
		"Second attack inside the 0.5s cooldown must be refused")
