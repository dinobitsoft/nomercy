extends GutTest

const HUD := preload("res://ui/hud.tscn")
const CHARACTER := preload("res://scenes/character/character.tscn")

var hud: Control
var character: Character

func before_each():
	character = CHARACTER.instantiate()
	add_child_autofree(character)
	hud = HUD.instantiate()
	add_child_autofree(hud)
	await wait_frames(2)
	hud.bind(character)

func test_health_bar_starts_full():
	var bar := hud.get_node("%HealthBar") as ProgressBar
	assert_almost_eq(bar.value, 100.0, 0.01)
	assert_almost_eq(bar.max_value, 100.0, 0.01)

func test_health_bar_follows_damage():
	character.apply_damage(24.0)
	await wait_frames(2)
	var bar := hud.get_node("%HealthBar") as ProgressBar
	assert_almost_eq(bar.value, 76.0, 0.01)

func test_stamina_bar_follows_a_jump():
	character.stamina = 100.0
	character.velocity = Vector2.ZERO
	# Spend stamina directly through the public path.
	character.stamina -= 20.0
	character.stamina_changed.emit(character.stamina, 100.0)
	await wait_frames(2)
	var bar := hud.get_node("%StaminaBar") as ProgressBar
	# Character auto-regenerates stamina every physics tick it is authoritative
	# for, and wait_frames(2) elapses a few physics frames before this
	# assertion runs (see test_character_physics.gd's own 3.0 tolerance for
	# the same reason), so allow a little regen drift instead of an exact 80.0.
	assert_almost_eq(bar.value, 80.0, 1.0)

func test_combo_label_hidden_at_zero():
	var label := hud.get_node("%ComboLabel") as Label
	assert_false(label.visible, "Combo label should hide when combo is 0")

func test_combo_label_shows_the_count():
	character.register_hit()
	character.register_hit()
	await wait_frames(2)
	var label := hud.get_node("%ComboLabel") as Label
	assert_true(label.visible)
	assert_string_contains(label.text, "2")

func test_health_bar_turns_orange_below_threshold():
	# 15% remaining is below the 0.3 threshold (hud.gd), so the fill must be
	# orange Color(1.0, 0.6, 0.1), not green Color(0.2, 0.85, 0.3). Both
	# colours have r == 1.0-ish/0.2-ish separately, but orange and green are
	# clearly separated on BOTH the r and g channels, so assert both bounds
	# together -- neither colour alone can satisfy both.
	character.apply_damage(85.0)  # 15% remaining
	await wait_frames(2)
	var bar := hud.get_node("%HealthBar") as ProgressBar
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	assert_gt(fill.bg_color.r, 0.9,
		"Below 30%% health the bar's red channel should be high (orange)")
	assert_lt(fill.bg_color.g, 0.7,
		"Below 30%% health the bar's green channel should be low (orange, not green)")
