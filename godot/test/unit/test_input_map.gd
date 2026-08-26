extends GutTest

const REQUIRED_ACTIONS := [
	"move_left", "move_right", "jump", "attack",
	"block", "dodge", "crouch", "pause",
]

func test_all_gameplay_actions_exist():
	for action in REQUIRED_ACTIONS:
		assert_true(
			InputMap.has_action(action),
			"Missing InputMap action: %s" % action
		)

func test_every_action_has_a_keyboard_and_a_joypad_binding():
	for action in REQUIRED_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var has_key := false
		var has_pad := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				has_key = true
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		assert_true(has_key, "%s has no keyboard binding" % action)
		assert_true(has_pad, "%s has no joypad binding" % action)
