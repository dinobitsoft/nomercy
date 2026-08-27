## Base character. Owns and mutates its own health, stamina and combo, and
## only when it holds multiplayer authority. Nothing outside this script
## writes those properties — that rule is what makes MultiplayerSynchronizer
## replication work without restructuring later.
##
## Ported from modules/engine/lib/src/components/character/game_character.dart
class_name Character
extends CharacterBody2D

signal died
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal combo_changed(count: int)

const GRAVITY := 1000.0
const MAX_FALL_SPEED := 800.0
const JUMP_VELOCITY := -300.0
const COMBO_WINDOW := 1.5

@export var stats: CharacterStats
@export var movement: MovementProfile

var health: float = 100.0
var stamina: float = 100.0
var combo: int = 0
var facing_right: bool = true

var _attack_cooldown: float = 0.0
var _combo_timer: float = 0.0
var _is_blocking: bool = false
var _dead: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _sm: CharacterStateMachine = $StateMachine

func _ready() -> void:
	if stats != null:
		health = stats.max_health
	stamina = 100.0
	health_changed.emit(health, _max_health())
	stamina_changed.emit(stamina, 100.0)

func is_authority() -> bool:
	# Single-player and headless tests have no multiplayer peer configured,
	# in which case every node is its own authority. This guard is inert
	# now and load-bearing in Phase 6.
	return not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()

func _max_health() -> float:
	return stats.max_health if stats != null else 100.0

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()
	_sync_animation()

	if not is_authority():
		return

	_tick_timers(delta)
	_tick_stamina(delta)

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

func _sync_animation() -> void:
	var want: CharacterStateMachine.State
	if _dead:
		want = CharacterStateMachine.State.DEAD
	elif not is_on_floor():
		want = CharacterStateMachine.State.JUMPING if velocity.y < 0.0 \
			else CharacterStateMachine.State.FALLING
	elif _is_blocking:
		want = CharacterStateMachine.State.BLOCKING
	elif absf(velocity.x) > 15.0:
		# GameConfig.walkThreshold = 15.0
		var running := absf(velocity.x) > \
			MovementProfile.base_speed(stats.dexterity) * movement.walk_multiplier
		want = CharacterStateMachine.State.RUNNING if running \
			else CharacterStateMachine.State.WALKING
	else:
		want = CharacterStateMachine.State.IDLE
	_sm.request(want)
	var anim := _sm.animation_for(_sm.state)
	if _sprite.animation != anim:
		_sprite.play(anim)

func _tick_timers(delta: float) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 0
			combo_changed.emit(combo)

func _tick_stamina(delta: float) -> void:
	var before := stamina
	if _is_blocking:
		stamina = Stamina.block_drain(stamina, delta)
		if stamina <= 0.0:
			stop_block()
	elif stamina < 100.0:
		stamina = Stamina.regen(stamina, 100.0, delta)
	if not is_equal_approx(before, stamina):
		stamina_changed.emit(stamina, 100.0)

## Horizontal movement. [param input] is the signed axis value in [-1, 1];
## its magnitude selects walk vs run exactly as resolveSpeed() does in Dart.
func move_horizontal(input: float, attack_committed: bool) -> void:
	if not is_authority():
		return
	if is_zero_approx(input):
		velocity.x = 0.0
		return
	var speed := movement.resolve_speed(
		stats.dexterity, absf(input), attack_committed
	)
	velocity.x = signf(input) * speed
	facing_right = input > 0.0
	_sprite.flip_h = not facing_right

func try_jump() -> bool:
	if not is_authority():
		return false
	if not is_on_floor():
		return false
	if not Stamina.can_jump(stamina):
		return false
	stamina -= Stamina.JUMP_COST
	stamina_changed.emit(stamina, 100.0)
	velocity.y = JUMP_VELOCITY
	return true

func start_block() -> void:
	if not is_authority():
		return
	if not Stamina.can_block(stamina):
		return
	_is_blocking = true

func stop_block() -> void:
	_is_blocking = false

func is_blocking() -> bool:
	return _is_blocking

func can_attack() -> bool:
	return _attack_cooldown <= 0.0 and Stamina.can_attack(stamina)

## Spends stamina and starts the cooldown. Returns false if the attack
## cannot start. Damage application is Task 11.
func begin_attack() -> bool:
	if not is_authority():
		return false
	if not can_attack():
		return false
	var airborne := not is_on_floor()
	stamina -= Stamina.attack_cost(airborne)
	_attack_cooldown = Stamina.attack_cooldown(airborne)
	stamina_changed.emit(stamina, 100.0)
	return true

func register_hit() -> void:
	if not is_authority():
		return
	combo += 1
	_combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)

func apply_damage(amount: float) -> void:
	if not is_authority():
		return
	if _dead:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, _max_health())
	if health <= 0.0:
		_dead = true
		died.emit()
