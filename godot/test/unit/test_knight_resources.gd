extends GutTest

var stats: CharacterStats
var move: MovementProfile

func before_each():
	stats = load("res://resources/knight_stats.tres") as CharacterStats
	move = load("res://resources/knight_movement.tres") as MovementProfile

func test_resources_load():
	assert_not_null(stats, "knight_stats.tres failed to load")
	assert_not_null(move, "knight_movement.tres failed to load")

func test_knight_stats_match_dart_source():
	# knight.dart KnightStats
	assert_eq(stats.char_name, "Knight")
	assert_almost_eq(stats.power, 15.0, 1e-6)
	assert_almost_eq(stats.magic, 5.0, 1e-6)
	assert_almost_eq(stats.dexterity, 8.0, 1e-6)
	assert_almost_eq(stats.intelligence, 7.0, 1e-6)
	assert_almost_eq(stats.attack_range, 2.0, 1e-6)
	assert_almost_eq(stats.attack_damage, 15.0, 1e-6)
	assert_almost_eq(stats.max_health, 100.0, 1e-6)
	assert_eq(stats.weapon_name, "Sword Slash")

func test_knight_movement_matches_dart_source():
	# knight_movement_strategy.dart
	assert_almost_eq(move.walk_multiplier, 100.0, 1e-6)
	assert_almost_eq(move.run_multiplier, 160.0, 1e-6)
	assert_almost_eq(move.run_threshold, 0.8, 1e-6)
	assert_almost_eq(move.attack_move_multiplier, 0.3, 1e-6)

func test_base_speed_is_dexterity_over_two():
	# game_character.dart:260 -> baseSpeed: stats.dexterity / 2
	assert_almost_eq(MovementProfile.base_speed(stats.dexterity), 4.0, 1e-6)

func test_knight_walk_speed_is_400_px_per_second():
	var speed := MovementProfile.base_speed(stats.dexterity) * move.walk_multiplier
	assert_almost_eq(speed, 400.0, 1e-6)

func test_knight_run_speed_is_640_px_per_second():
	var speed := MovementProfile.base_speed(stats.dexterity) * move.run_multiplier
	assert_almost_eq(speed, 640.0, 1e-6)

func test_melee_reach_at_combo_zero_is_sixty_px():
	assert_almost_eq(Combat.melee_reach(stats.attack_range, 0), 60.0, 1e-6)
