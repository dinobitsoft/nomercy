## Translates InputMap actions into Character calls.
##
## This node is the ONLY place in the project that reads input. It never
## touches a device — only named actions — so keyboard, gamepad and the
## touch joystick all arrive through the same path.
class_name PlayerController
extends Node

@onready var _character: Character = get_parent() as Character

func _ready() -> void:
	assert(_character != null, "PlayerController must be a child of a Character")

func _physics_process(_delta: float) -> void:
	if not _character.is_authority():
		return

	var axis := Input.get_axis("move_left", "move_right")
	_character.move_horizontal(axis, false)

	if Input.is_action_just_pressed("jump"):
		_character.try_jump()

	if Input.is_action_just_pressed("attack"):
		_character.perform_melee_attack()

	if Input.is_action_pressed("block"):
		_character.start_block()
	else:
		_character.stop_block()
