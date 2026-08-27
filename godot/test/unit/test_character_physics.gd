extends GutTest

const CHARACTER := preload("res://scenes/character/character.tscn")
const PLATFORM := preload("res://scenes/platform/platform.tscn")

var character: Character
var platform: Node2D

func before_each():
	platform = PLATFORM.instantiate()
	platform.position = Vector2(0, 500)
	platform.size = Vector2(1000, 80)
	platform.kind = Platform.Kind.GROUND
	add_child_autofree(platform)

	character = CHARACTER.instantiate()
	character.position = Vector2(400, 100)
	add_child_autofree(character)
	await wait_frames(2)

func test_starts_at_full_health_and_stamina():
	assert_almost_eq(character.health, 100.0, 1e-6)
	assert_almost_eq(character.stamina, 100.0, 1e-6)
	assert_eq(character.combo, 0)

func test_gravity_pulls_character_down():
	var start_y := character.position.y
	await wait_physics_frames(10)
	assert_gt(character.position.y, start_y,
		"Character should fall under gravity")

func test_character_lands_on_platform_and_stops():
	await wait_seconds(2.0)
	assert_true(character.is_on_floor(), "Character should land on the platform")
	assert_almost_eq(character.velocity.y, 0.0, 1.0)

func test_fall_speed_is_capped_at_800():
	# Remove the floor so it falls freely.
	platform.queue_free()
	await wait_seconds(3.0)
	assert_lte(character.velocity.y, 800.0 + 1.0,
		"Fall speed must clamp at maxFallSpeed = 800")

func test_jump_costs_twenty_stamina():
	await wait_seconds(2.0)  # land first
	var before := character.stamina
	character.try_jump()
	assert_almost_eq(character.stamina, before - 20.0, 1e-6)

func test_jump_sets_upward_velocity():
	await wait_seconds(2.0)
	character.try_jump()
	assert_almost_eq(character.velocity.y, -300.0, 1e-6)

func test_jump_is_refused_without_stamina():
	await wait_seconds(2.0)
	character.stamina = 10.0
	var refused := not character.try_jump()
	assert_true(refused, "Jump must be refused below 20 stamina")
	assert_almost_eq(character.stamina, 10.0, 1e-6)

func test_stamina_regenerates_at_fifteen_per_second():
	await wait_seconds(2.0)
	character.stamina = 50.0
	await wait_seconds(1.0)
	# Allow generous tolerance — frame timing is not exact.
	assert_almost_eq(character.stamina, 65.0, 3.0)

func test_apply_damage_reduces_health():
	character.apply_damage(24.0)
	assert_almost_eq(character.health, 76.0, 1e-6)

func test_health_floors_at_zero():
	character.apply_damage(500.0)
	assert_almost_eq(character.health, 0.0, 1e-6)

func test_died_signal_fires_once_at_zero_health():
	watch_signals(character)
	character.apply_damage(500.0)
	assert_signal_emit_count(character, "died", 1)
	character.apply_damage(10.0)
	assert_signal_emit_count(character, "died", 1, "died must not re-fire")
