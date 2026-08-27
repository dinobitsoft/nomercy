## Character animation/action states. Ported verbatim from
## modules/engine/lib/src/statemachine/character_animation_state.dart
class_name CharacterStateMachine
extends Node

signal state_changed(from: State, to: State)

enum State {
	IDLE, WALKING, RUNNING, JUMPING, FALLING,
	LANDING, ATTACKING, BLOCKING, DODGING, STUNNED, DEAD,
}

## Only these may interrupt a committed attack (game_character.dart treats
## attacks as committed for attackCommitTime = 0.3s).
const ATTACK_INTERRUPTS := [State.STUNNED, State.DEAD]

## FALLING reuses the jump art — there is no separate falling sprite.
const ANIMATIONS := {
	State.IDLE: "idle",
	State.WALKING: "walk",
	State.RUNNING: "run",
	State.JUMPING: "jump",
	State.FALLING: "jump",
	State.LANDING: "landing",
	State.ATTACKING: "attack",
	State.BLOCKING: "idle",
	State.DODGING: "walk",
	State.STUNNED: "idle",
	State.DEAD: "idle",
}

var state: State = State.IDLE

## Returns true if the transition was accepted.
func request(new_state: State) -> bool:
	if new_state == state:
		return false
	if state == State.DEAD:
		return false
	if state == State.ATTACKING and new_state not in ATTACK_INTERRUPTS:
		return false
	var previous := state
	state = new_state
	state_changed.emit(previous, state)
	return true

## Force a transition, ignoring commitment rules. Used when a timer
## expires — e.g. the attack animation finishing.
func force(new_state: State) -> void:
	if new_state == state:
		return
	var previous := state
	state = new_state
	state_changed.emit(previous, state)

func animation_for(s: State) -> String:
	return ANIMATIONS.get(s, "idle")
