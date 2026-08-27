## Drives a Character from BotDecision output.
##
## This node builds the WorldSnapshot and applies the chosen action; all
## judgement lives in the pure scripts/bot_decision.gd. Runs only on the
## authority, so in multiplayer the host simulates every enemy.
class_name BotController
extends Node

@export var personality: BotPersonality

var target: Character
var decisions_made: int = 0

var _cooldown: float = 0.0
var _action: String = "idle"

@onready var _character: Character = get_parent() as Character

func _ready() -> void:
	assert(_character != null, "BotController must be a child of a Character")

func _physics_process(delta: float) -> void:
	if not _character.is_authority():
		return
	if target == null or personality == null:
		return
	if _character.health <= 0.0:
		return

	_cooldown -= delta
	if _cooldown <= 0.0:
		_action = BotDecision.decide(_build_snapshot(), personality)
		decisions_made += 1
		_cooldown = personality.reaction_time

	_apply(_action)

func _build_snapshot() -> WorldSnapshot:
	var s := WorldSnapshot.new()
	s.distance_to_target = _character.global_position.distance_to(
		target.global_position
	)
	s.health_percent = _character.health / _character.stats.max_health
	s.stamina = _character.stamina
	s.target_is_attacking = not target.can_attack()
	s.target_is_blocking = target.is_blocking()
	s.projectile_incoming = false  # No projectiles in the slice (Knight is melee).
	s.is_grounded = _character.is_on_floor()
	s.melee_reach = Combat.melee_reach(
		_character.stats.attack_range, _character.combo
	)
	return s

func _apply(action: String) -> void:
	var dx := target.global_position.x - _character.global_position.x
	var toward: float = signf(dx)

	match action:
		"attack":
			# attack_committed=true applies MovementProfile's reduced
			# attack_move_multiplier, so the bot keeps closing on a target
			# that knockback has pushed just out of comfortable range
			# instead of planting its feet and letting the gap grow.
			_character.move_horizontal(toward, true)
			_character.face(toward > 0.0)
			_character.perform_melee_attack()
		"approach":
			_character.stop_block()
			_character.move_horizontal(toward, false)
		"retreat":
			_character.stop_block()
			_character.move_horizontal(-toward, false)
		"block":
			_character.move_horizontal(0.0, false)
			_character.face(toward > 0.0)
			_character.start_block()
		"dodge":
			_character.move_horizontal(-toward, false)
		_:
			_character.move_horizontal(0.0, false)
			_character.stop_block()
