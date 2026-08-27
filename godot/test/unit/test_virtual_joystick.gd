extends GutTest

const JOYSTICK := preload("res://ui/touch_controls.tscn")

var controls: Control

func before_each():
	controls = JOYSTICK.instantiate()
	add_child_autofree(controls)
	await wait_frames(2)

func after_each():
	for action in ["move_left", "move_right", "jump", "attack", "block"]:
		Input.action_release(action)

func test_hidden_when_there_is_no_touchscreen():
	# CI and desktop have no touchscreen; the controls must not block input.
	if not DisplayServer.is_touchscreen_available():
		assert_false(controls.get_node("%Joystick").visible,
			"Touch controls must hide on non-touch devices")
	else:
		pass_test("Touchscreen present; visibility check not applicable")

func test_dragging_right_presses_move_right():
	var stick := controls.get_node("%Joystick")
	stick.set_vector(Vector2(1.0, 0.0))
	await wait_frames(2)
	assert_true(Input.is_action_pressed("move_right"))
	assert_almost_eq(Input.get_action_strength("move_right"), 1.0, 0.01)

func test_dragging_left_presses_move_left():
	var stick := controls.get_node("%Joystick")
	stick.set_vector(Vector2(-1.0, 0.0))
	await wait_frames(2)
	assert_true(Input.is_action_pressed("move_left"))

func test_partial_deflection_reports_partial_strength():
	var stick := controls.get_node("%Joystick")
	stick.set_vector(Vector2(0.5, 0.0))
	await wait_frames(2)
	assert_almost_eq(Input.get_action_strength("move_right"), 0.5, 0.05,
		"Analog strength must survive so walk-vs-run still works")

func test_recentering_releases_both_directions():
	var stick := controls.get_node("%Joystick")
	stick.set_vector(Vector2(1.0, 0.0))
	await wait_frames(2)
	stick.set_vector(Vector2.ZERO)
	await wait_frames(2)
	assert_false(Input.is_action_pressed("move_right"))
	assert_false(Input.is_action_pressed("move_left"))

func test_deadzone_is_ignored():
	var stick := controls.get_node("%Joystick")
	stick.set_vector(Vector2(0.1, 0.0))
	await wait_frames(2)
	assert_false(Input.is_action_pressed("move_right"),
		"0.1 is inside the 0.2 deadzone")

## Parameterised: attack/jump/block on-screen buttons must feed the same
## InputMap actions as keyboard/gamepad, via the button's
## button_down/button_up signals -> touch_action_button.gd -> GameVirtualJoystick.tap()/release().
func test_action_buttons_press_and_release_their_input_action():
	var button_names := {
		"attack": "%AttackButton",
		"jump": "%JumpButton",
		"block": "%BlockButton",
	}
	for action in button_names:
		var button := controls.get_node(button_names[action]) as Button
		assert_false(Input.is_action_pressed(action),
			"%s should start released" % action)

		button.emit_signal("button_down")
		await wait_frames(2)
		assert_true(Input.is_action_pressed(action),
			"Pressing the %s button should press the %s action" % [button_names[action], action])

		button.emit_signal("button_up")
		await wait_frames(2)
		assert_false(Input.is_action_pressed(action),
			"Releasing the %s button should release the %s action" % [button_names[action], action])
