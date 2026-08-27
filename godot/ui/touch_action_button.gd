## On-screen button that feeds an InputMap action, via GameVirtualJoystick's
## tap()/release() -- the same publish path the joystick uses for movement,
## so gameplay code cannot tell this apart from keyboard/gamepad input.
##
## Hides on non-touch devices exactly like Joystick does.
extends Button

## Name of the InputMap action this button drives (e.g. "attack").
@export var input_action: String = ""

func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available()
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_button_down() -> void:
	if input_action != "":
		GameVirtualJoystick.tap(input_action)

func _on_button_up() -> void:
	if input_action != "":
		GameVirtualJoystick.release(input_action)
