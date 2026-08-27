extends GutTest

const ENEMY := preload("res://scenes/character/enemy.tscn")
const PLAYER := preload("res://scenes/character/player.tscn")
const PLATFORM := preload("res://scenes/platform/platform.tscn")

var enemy: Character
var player: Character

func before_each():
	var floor_node = PLATFORM.instantiate()
	floor_node.position = Vector2(0, 500)
	floor_node.size = Vector2(3000, 80)
	add_child_autofree(floor_node)

	player = PLAYER.instantiate()
	player.position = Vector2(400, 260)
	add_child_autofree(player)

	enemy = ENEMY.instantiate()
	enemy.position = Vector2(1200, 260)
	add_child_autofree(enemy)
	enemy.get_node("BotController").target = player

	await wait_seconds(1.5)

func test_enemy_is_flagged_as_an_enemy():
	assert_true(enemy.is_enemy)

func test_enemy_has_the_aggressive_personality():
	var p: BotPersonality = enemy.get_node("BotController").personality
	assert_not_null(p)
	assert_eq(p.personality_name, "Aggressive")

func test_enemy_closes_distance_to_a_distant_player():
	var start := enemy.global_position.distance_to(player.global_position)
	await wait_seconds(1.5)
	var now := enemy.global_position.distance_to(player.global_position)
	assert_lt(now, start, "An aggressive bot should close the gap")

func test_enemy_faces_the_player_while_approaching():
	await wait_seconds(0.5)
	# Player is to the left of the enemy, so it should face left.
	assert_false(enemy.facing_right)

func test_enemy_damages_the_player_once_in_range():
	enemy.position = Vector2(440, 260)
	await wait_seconds(2.0)
	assert_lt(player.health, 100.0,
		"An aggressive bot in reach should land a hit")

func test_decisions_are_throttled_by_reaction_time():
	var controller: BotController = enemy.get_node("BotController")
	var first: int = controller.decisions_made
	await wait_seconds(0.5)
	var made: int = controller.decisions_made - first
	# reaction_time 0.15s over 0.5s -> roughly 3-4 decisions, not 30.
	assert_between(made, 1, 8,
		"Expected throttled decisions, got %d" % made)

func test_sustained_attacking_does_not_increase_distance():
	# Melee range against a stationary player: this pins the invariant the
	# attack-branch rewrite exists to protect. Previously the bot planted
	# its feet while attacking and combo-driven reach growth outran
	# knockback separation, letting the raw gap creep outward forever.
	# This alone does NOT discriminate round-1's overspeed fix from round-2's
	# correct one (both keep the bot within the starting gap here) -- see
	# test_attack_state_shuffle_speed_is_bounded below for that.
	enemy.position = Vector2(440, 260)
	var start := enemy.global_position.distance_to(player.global_position)
	await wait_seconds(2.0)
	var now := enemy.global_position.distance_to(player.global_position)
	assert_lte(now, start,
		"Sustained attacking should not let the gap to the player grow")

func test_attack_state_shuffle_speed_is_bounded():
	# Pins the actual round-1 vs round-2 divergence. Round-1 routed the
	# attack-branch shuffle through move_horizontal(toward, true): toward has
	# magnitude 1.0, which exceeds run_threshold, so that produced ~192 px/s
	# (run_multiplier x attack_move_multiplier x base_speed). Round-2 assigns
	# velocity.x directly at ATTACK_RETREAT_SPEED (30 px/s). A bound of 60 is
	# comfortably above round-2's 30 and comfortably below round-1's 192, so
	# it fails round-1's code and passes round-2's.
	#
	# Only sampled on frames where the controller's current action is
	# "attack" -- closing a large initial gap legitimately runs at full
	# move_horizontal() speed (~640 px/s) via the unrelated "approach"
	# action, and that is not what this test is about.
	enemy.position = Vector2(440, 260)
	var controller: BotController = enemy.get_node("BotController")
	var max_attack_speed := 0.0
	for i in range(120):
		await get_tree().physics_frame
		if controller._action == "attack":
			max_attack_speed = maxf(max_attack_speed, absf(enemy.velocity.x))
	assert_lt(max_attack_speed, 60.0,
		("Attack-state shuffle speed should stay near ATTACK_RETREAT_SPEED " +
		"(30), not move_horizontal() run speed (192): got %.1f") % max_attack_speed)
