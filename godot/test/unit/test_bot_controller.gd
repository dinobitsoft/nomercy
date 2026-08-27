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
