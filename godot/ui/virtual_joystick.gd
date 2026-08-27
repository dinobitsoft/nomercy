## Touch stick that emits InputEventAction, so touch arrives through the
## same InputMap actions as keyboard and gamepad. Gameplay code cannot
## tell the difference — that is the whole point of the indirection.
##
## NOTE: Godot 4.7 ships a native "VirtualJoystick" class; naming this
## class_name the same causes a hard parse error ("hides a native class").
## Named GameVirtualJoystick to avoid the collision. Nothing in this
## project's tests or scenes reference the class name directly (the
## script is looked up via node path, e.g. %Joystick), so this rename
## is safe.
class_name GameVirtualJoystick
extends Control

const DEADZONE := 0.2

var _vector: Vector2 = Vector2.ZERO
var _touch_index: int = -1

@onready var _knob: Control = $Knob

func _ready() -> void:
	# Hide on devices without touch so it never eats mouse clicks.
	visible = DisplayServer.is_touchscreen_available()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_update_from_position(event.position)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			set_vector(Vector2.ZERO)
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_from_position(event.position)

func _update_from_position(local_position: Vector2) -> void:
	var radius: float = size.x / 2.0
	var offset := local_position - size / 2.0
	set_vector((offset / radius).limit_length(1.0))

## Sets the stick vector and republishes the movement actions.
## Public so tests can drive it without synthesising touch events.
func set_vector(v: Vector2) -> void:
	_vector = v
	if is_instance_valid(_knob):
		_knob.position = size / 2.0 + v * (size.x / 2.0) - _knob.size / 2.0
	_publish("move_right", maxf(0.0, v.x))
	_publish("move_left", maxf(0.0, -v.x))

func get_vector() -> Vector2:
	return _vector

func _publish(action: String, strength: float) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	if strength > DEADZONE:
		ev.pressed = true
		ev.strength = strength
	else:
		ev.pressed = false
		ev.strength = 0.0
	Input.parse_input_event(ev)

## Used by the on-screen buttons in touch_controls.tscn.
static func tap(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	down.strength = 1.0
	Input.parse_input_event(down)

static func release(action: String) -> void:
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
