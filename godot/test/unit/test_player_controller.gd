extends GutTest

const PLAYER := preload("res://scenes/character/player.tscn")
const PLATFORM := preload("res://scenes/platform/platform.tscn")

var player: Character

func before_each():
	var floor_node = PLATFORM.instantiate()
	floor_node.position = Vector2(0, 500)
	floor_node.size = Vector2(2000, 80)
	add_child_autofree(floor_node)

	player = PLAYER.instantiate()
	player.position = Vector2(400, 260)
	add_child_autofree(player)
	await wait_seconds(1.5)

func after_each():
	# Release everything so state cannot leak between tests.
	for action in ["move_left", "move_right", "jump", "attack", "block", "dodge"]:
		Input.action_release(action)

func test_player_is_not_an_enemy():
	assert_false(player.is_enemy)

func test_move_right_action_produces_positive_velocity():
	Input.action_press("move_right", 1.0)
	await wait_physics_frames(3)
	assert_gt(player.velocity.x, 0.0)
	assert_true(player.facing_right)

func test_move_left_action_produces_negative_velocity():
	Input.action_press("move_left", 1.0)
	await wait_physics_frames(3)
	assert_lt(player.velocity.x, 0.0)
	assert_false(player.facing_right)

func test_full_stick_deflection_runs_at_640():
	Input.action_press("move_right", 1.0)
	await wait_physics_frames(3)
	assert_almost_eq(absf(player.velocity.x), 640.0, 1.0,
		"Input magnitude 1.0 > runThreshold 0.8 -> run speed")

func test_partial_deflection_walks_at_400():
	Input.action_press("move_right", 0.5)
	await wait_physics_frames(3)
	assert_almost_eq(absf(player.velocity.x), 400.0, 1.0,
		"Input magnitude 0.5 <= runThreshold 0.8 -> walk speed")

func test_jump_action_lifts_the_player():
	Input.action_press("jump")
	await wait_physics_frames(2)
	assert_lt(player.velocity.y, 0.0, "Jump should produce upward velocity")

func test_block_action_sets_blocking():
	Input.action_press("block")
	await wait_physics_frames(2)
	assert_true(player.is_blocking())

func test_releasing_block_clears_blocking():
	Input.action_press("block")
	await wait_physics_frames(2)
	Input.action_release("block")
	await wait_physics_frames(2)
	assert_false(player.is_blocking())

func test_no_input_leaves_the_player_stationary():
	await wait_physics_frames(3)
	assert_almost_eq(player.velocity.x, 0.0, 0.01)
