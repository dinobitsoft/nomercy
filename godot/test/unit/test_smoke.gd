extends GutTest

func test_gut_runs():
	assert_true(true, "GUT is wired up")

func test_godot_version_is_4_7_or_later():
	var info := Engine.get_version_info()
	assert_true(
		info.major > 4 or (info.major == 4 and info.minor >= 7),
		"Expected Godot >= 4.7, got %d.%d" % [info.major, info.minor]
	)
