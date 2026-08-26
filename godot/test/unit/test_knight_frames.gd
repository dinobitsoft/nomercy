extends GutTest

const FRAMES_PATH := "res://resources/knight_frames.tres"

var frames: SpriteFrames

func before_each():
	frames = load(FRAMES_PATH) as SpriteFrames

func test_resource_loads():
	assert_not_null(frames, "knight_frames.tres failed to load")

func test_has_all_six_animations():
	for anim in ["idle", "walk", "run", "attack", "jump", "landing"]:
		assert_true(frames.has_animation(anim), "Missing animation: %s" % anim)

func test_walk_has_six_frames():
	assert_eq(frames.get_frame_count("walk"), 6, "Knight walk is a 6-frame cycle")

func test_run_has_six_frames():
	assert_eq(frames.get_frame_count("run"), 6, "Knight run reuses the walk frames")

func test_static_animations_have_one_frame():
	for anim in ["idle", "attack", "jump", "landing"]:
		assert_eq(frames.get_frame_count(anim), 1,
			"%s is a single static image in the source game" % anim)

func test_step_times_match_dart_movement_strategy():
	# knight_movement_strategy.dart: idle 0.20, walk 0.13, run 0.09
	# SpriteFrames stores FPS, so fps == 1.0 / step_time
	assert_almost_eq(frames.get_animation_speed("idle"), 1.0 / 0.20, 0.01)
	assert_almost_eq(frames.get_animation_speed("walk"), 1.0 / 0.13, 0.01)
	assert_almost_eq(frames.get_animation_speed("run"), 1.0 / 0.09, 0.01)

func test_walk_frame_order_alternates_correctly():
	# Frames 0 and 3 are the same source image (left_leg_front);
	# frames 1 and 4 are the same (legs_together). Verifying the texture
	# identity catches a mis-ordered cycle.
	assert_eq(frames.get_frame_texture("walk", 0), frames.get_frame_texture("walk", 3))
	assert_eq(frames.get_frame_texture("walk", 1), frames.get_frame_texture("walk", 4))
	assert_eq(frames.get_frame_texture("walk", 0), frames.get_frame_texture("walk", 5))
