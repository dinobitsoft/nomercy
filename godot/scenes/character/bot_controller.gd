## Drives a Character from BotDecision output.
##
## This node builds the WorldSnapshot and applies the chosen action; all
## judgement lives in the pure scripts/bot_decision.gd. Runs only on the
## authority, so in multiplayer the host simulates every enemy.
class_name BotController
extends Node

@export var personality: BotPersonality

## Dart's smart_bot_ai.dart _performAttack() is a three-way rule: approach when
## beyond optimal_range, back away when inside optimal_range * 0.7, hold otherwise.
## We keep that structure and Dart's 4:3 approach:retreat ratio, but scale the raw
## magnitudes up. Dart's literal speeds (dexterity/3 = 2.67 px/s, dexterity/4 = 2.0)
## cannot hold a melee bot on target: combo-driven reach growth outruns knockback
## separation, so the bot drifts away while staying attack-locked. Assigned directly
## to velocity.x like Dart does — NOT routed through MovementProfile, which is the
## human-player input path and produces a ~72x overspeed here.
const ATTACK_APPROACH_SPEED := 40.0
const ATTACK_RETREAT_SPEED  := 30.0

## NOTE for future personalities (Phase 2): under today's numbers, only the
## retreat branch below is ever reachable. _score_attack (bot_decision.gd)
## only scores "attack" once distance < melee_reach, and Knight melee_reach
## tops out at ~84px (combo 4), while optimal_range * 0.7 = 105 for every
## personality shipped so far -- so distance is always < optimal_range * 0.7
## whenever "attack" is chosen, and the "dist > optimal" / neutral branches
## are dead code, kept only for structural fidelity with Dart's three-way
## rule. They would only become reachable if a personality's optimal_range
## were tuned down, or attack_range/combo scaling tuned up, enough to push
## melee_reach past optimal_range * 0.7.

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
			_character.face(toward > 0.0)
			var dist := _character.global_position.distance_to(target.global_position)
			var optimal := personality.optimal_range
			if dist > optimal:
				_character.velocity.x = toward * ATTACK_APPROACH_SPEED
			elif dist < optimal * 0.7:
				_character.velocity.x = -toward * ATTACK_RETREAT_SPEED
			else:
				_character.velocity.x = 0.0
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
