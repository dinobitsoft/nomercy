extends GutTest

var level: Node2D

func before_each():
	var packed := load("res://scenes/maps/level_1.tscn") as PackedScene
	assert_not_null(packed, "level_1.tscn failed to load")
	level = packed.instantiate()
	add_child_autofree(level)

func test_has_twenty_four_platforms():
	# assets/maps/level_1.json: 24 platforms (6 brick, 18 ground)
	assert_eq(level.get_node("Platforms").get_child_count(), 24)

func test_platform_kinds_match_source_counts():
	var brick := 0
	var ground := 0
	for p in level.get_node("Platforms").get_children():
		if p.kind == Platform.Kind.BRICK:
			brick += 1
		elif p.kind == Platform.Kind.GROUND:
			ground += 1
	assert_eq(brick, 6, "level_1.json has 6 brick platforms")
	assert_eq(ground, 18, "level_1.json has 18 ground platforms")

func test_player_spawn_matches_source():
	var spawn := level.get_node("PlayerSpawn") as Marker2D
	assert_almost_eq(spawn.position.x, 200.0, 0.5)
	assert_almost_eq(spawn.position.y, 900.0, 0.5)

func test_first_platform_position_and_size_match_source():
	# First record: brick at (71, 607), 120x30
	var first := level.get_node("Platforms").get_child(0) as Platform
	assert_almost_eq(first.position.x, 71.0, 0.5)
	assert_almost_eq(first.position.y, 607.0, 0.5)
	assert_almost_eq(first.size.x, 120.0, 0.5)
	assert_almost_eq(first.size.y, 30.0, 0.5)

func test_all_platforms_have_collision_shapes():
	for p in level.get_node("Platforms").get_children():
		var shape := p.get_node("CollisionShape2D") as CollisionShape2D
		assert_not_null(shape.shape, "%s has no collision shape" % p.name)
