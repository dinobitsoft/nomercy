extends GutTest

const LEVEL := preload("res://scenes/maps/level_1.tscn")

var level: Node2D

func before_each():
	level = LEVEL.instantiate()
	add_child_autofree(level)
	await wait_seconds(2.0)

func after_each():
	for action in ["move_left", "move_right", "jump", "attack", "block"]:
		Input.action_release(action)

func test_player_spawns_at_the_marker():
	var player := level.get_node("Player") as Character
	assert_not_null(player)
	# Spawned at (200, 900); it will have fallen to a platform by now.
	assert_almost_eq(player.global_position.x, 200.0, 5.0)

func test_player_lands_on_a_platform_rather_than_falling_forever():
	var player := level.get_node("Player") as Character
	assert_true(player.is_on_floor(),
		"Player must come to rest on level geometry")

func test_enemy_exists_and_targets_the_player():
	var enemy := level.get_node("Enemy") as Character
	assert_not_null(enemy)
	assert_eq(enemy.get_node("BotController").target, level.get_node("Player"))

func test_hud_is_bound_to_the_player():
	var hud := level.get_node("UILayer/HUD")
	var bar := hud.get_node("%HealthBar") as ProgressBar
	var player := level.get_node("Player") as Character
	player.apply_damage(10.0)
	await wait_frames(3)
	assert_almost_eq(bar.value, 90.0, 0.01)

func test_enemy_closes_on_the_player_over_time():
	var player := level.get_node("Player") as Character
	var enemy := level.get_node("Enemy") as Character
	var start := enemy.global_position.distance_to(player.global_position)
	await wait_seconds(2.0)
	var now := enemy.global_position.distance_to(player.global_position)
	assert_lt(now, start)

func test_player_input_moves_the_player():
	var player := level.get_node("Player") as Character
	var start_x := player.global_position.x
	Input.action_press("move_right", 1.0)
	await wait_seconds(0.5)
	assert_gt(player.global_position.x, start_x + 50.0)
