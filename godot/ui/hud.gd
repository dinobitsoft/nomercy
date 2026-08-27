## Health, stamina and combo readout.
##
## Signal-driven: it subscribes to the bound Character and never polls or
## writes character state. Colour thresholds match the Dart HUD
## (green -> orange -> red), with GameConfig.lowHealthThreshold = 0.2.
extends Control

const LOW_HEALTH := 0.2
const MID_HEALTH := 0.5

@onready var _health: ProgressBar = %HealthBar
@onready var _stamina: ProgressBar = %StaminaBar
@onready var _combo: Label = %ComboLabel

var _character: Character

func bind(character: Character) -> void:
	if _character != null:
		_character.health_changed.disconnect(_on_health_changed)
		_character.stamina_changed.disconnect(_on_stamina_changed)
		_character.combo_changed.disconnect(_on_combo_changed)

	# The stylebox returned by get_theme_stylebox() may be shared across
	# every ProgressBar in the project, so duplicate it before this HUD
	# ever mutates bg_color -- otherwise a low-health tint here would leak
	# into other bars.
	var fill := _health.get_theme_stylebox("fill")
	if fill != null:
		_health.add_theme_stylebox_override("fill", fill.duplicate())

	_character = character
	character.health_changed.connect(_on_health_changed)
	character.stamina_changed.connect(_on_stamina_changed)
	character.combo_changed.connect(_on_combo_changed)

	_on_health_changed(character.health, character.stats.max_health)
	_on_stamina_changed(character.stamina, 100.0)
	_on_combo_changed(character.combo)

func _on_health_changed(current: float, maximum: float) -> void:
	_health.max_value = maximum
	_health.value = current
	var pct := current / maximum if maximum > 0.0 else 0.0
	var fill := _health.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		if pct <= LOW_HEALTH:
			fill.bg_color = Color(1.0, 0.2, 0.2)
		elif pct <= MID_HEALTH:
			fill.bg_color = Color(1.0, 0.6, 0.1)
		else:
			fill.bg_color = Color(0.2, 0.85, 0.3)

func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina.max_value = maximum
	_stamina.value = current

func _on_combo_changed(count: int) -> void:
	_combo.visible = count > 0
	_combo.text = "%d HIT COMBO" % count
