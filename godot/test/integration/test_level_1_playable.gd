extends GutTest

const LEVEL := preload("res://scenes/maps/level_1.tscn")
const PLAYER_SCENE := preload("res://scenes/character/player.tscn")
const HUD_SCENE := preload("res://ui/hud.tscn")

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

## Deliberately decoupled from `level`/the live combat scenario: this only
## verifies HUD.bind() wires a Character's signals to the health bar. It
## used to reuse the level's own Player and assert its health was still
## the untouched 100 at the 2s mark -- true only because the old spawn left
## the enemy airborne until after that mark. Now that the enemy engages
## quickly (see test_enemy_engages_the_player_in_melee below), that
## assumption no longer holds, and re-tuning the spawn to preserve it would
## just be routing around the bug this fixes. A captive Character with no
## enemy anywhere near it is the correct fixture for "is the HUD bound".
func test_hud_is_bound_to_the_player():
	var captive_player: Character = PLAYER_SCENE.instantiate()
	add_child_autofree(captive_player)
	var captive_hud: Control = HUD_SCENE.instantiate()
	add_child_autofree(captive_hud)
	captive_hud.bind(captive_player)
	var bar := captive_hud.get_node("%HealthBar") as ProgressBar
	captive_player.apply_damage(10.0)
	await wait_frames(3)
	assert_almost_eq(bar.value, 90.0, 0.01)

func test_enemy_closes_on_the_player_over_time():
	var player := level.get_node("Player") as Character
	var enemy := level.get_node("Enemy") as Character
	var start := enemy.global_position.distance_to(player.global_position)
	await wait_seconds(2.0)
	var now := enemy.global_position.distance_to(player.global_position)
	assert_lt(now, start)

## "Closes" alone doesn't prove the enemy is a threat -- it also passed
## when the enemy fell into a permanently stuck position 127px away, well
## outside melee_reach (60px), and simply never got any closer again after
## that. This asserts actual contact: the enemy must either close inside
## melee_reach of the player, or the player's health must already have
## dropped below max because a hit landed, within a bounded window.
func test_enemy_engages_the_player_in_melee():
	var player := level.get_node("Player") as Character
	var enemy := level.get_node("Enemy") as Character
	var reach := Combat.melee_reach(enemy.stats.attack_range, 0)
	var engaged := false
	for _i in range(20):
		var dist := enemy.global_position.distance_to(player.global_position)
		if dist < reach or player.health < player.stats.max_health:
			engaged = true
			break
		await wait_seconds(0.1)
	assert_true(engaged,
		"Enemy must actually reach melee range of the player, not merely approach and stall")

func test_player_input_moves_the_player():
	var player := level.get_node("Player") as Character
	var start_x := player.global_position.x
	Input.action_press("move_right", 1.0)
	await wait_seconds(0.5)
	assert_gt(player.global_position.x, start_x + 50.0)
