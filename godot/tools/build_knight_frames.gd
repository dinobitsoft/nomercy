@tool
extends SceneTree

const IMG := "res://assets/images/"

const WALK := [
	IMG + "warrior_walk_resized_left_leg_front.png",
	IMG + "warrior_walk_resized_legs_together_left_knee_front.png",
	IMG + "warrior_walk_resized_right_leg_front.png",
	IMG + "warrior_walk_resized_left_leg_front.png",
	IMG + "warrior_walk_resized_legs_together_left_knee_front.png",
	IMG + "warrior_walk_resized_left_leg_front.png",
]

func _init() -> void:
	var frames := SpriteFrames.new()
	# SpriteFrames starts with a "default" animation; drop it.
	frames.remove_animation("default")

	_add(frames, "idle", [IMG + "knight_idle.png"], 1.0 / 0.20, true)
	_add(frames, "walk", WALK, 1.0 / 0.13, true)
	_add(frames, "run", WALK, 1.0 / 0.09, true)
	_add(frames, "attack", [IMG + "knight_attack.png"], 1.0 / 0.30, false)
	_add(frames, "jump", [IMG + "knight_jump.png"], 1.0 / 0.20, true)
	_add(frames, "landing", [IMG + "knight_landing.png"], 1.0 / 0.25, false)

	var err := ResourceSaver.save(frames, "res://resources/knight_frames.tres")
	if err != OK:
		push_error("Save failed: %d" % err)
	else:
		print("Wrote res://resources/knight_frames.tres")
	quit()

func _add(frames: SpriteFrames, name: String, paths: Array,
		fps: float, loop: bool) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, fps)
	frames.set_animation_loop(name, loop)
	for p in paths:
		var tex := load(p) as Texture2D
		if tex == null:
			push_error("Missing texture: %s" % p)
			continue
		frames.add_frame(name, tex)
