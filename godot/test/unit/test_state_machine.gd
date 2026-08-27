extends GutTest

var sm: CharacterStateMachine

func before_each():
	sm = CharacterStateMachine.new()
	add_child_autofree(sm)

func test_starts_idle():
	assert_eq(sm.state, CharacterStateMachine.State.IDLE)

func test_idle_to_walking_is_allowed():
	assert_true(sm.request(CharacterStateMachine.State.WALKING))
	assert_eq(sm.state, CharacterStateMachine.State.WALKING)

func test_state_changed_signal_carries_from_and_to():
	watch_signals(sm)
	sm.request(CharacterStateMachine.State.JUMPING)
	assert_signal_emitted_with_parameters(
		sm, "state_changed",
		[CharacterStateMachine.State.IDLE, CharacterStateMachine.State.JUMPING]
	)

func test_requesting_current_state_is_a_noop():
	watch_signals(sm)
	assert_false(sm.request(CharacterStateMachine.State.IDLE))
	assert_signal_emit_count(sm, "state_changed", 0)

func test_dead_is_terminal():
	sm.request(CharacterStateMachine.State.DEAD)
	assert_false(sm.request(CharacterStateMachine.State.IDLE),
		"Nothing may transition out of DEAD")
	assert_eq(sm.state, CharacterStateMachine.State.DEAD)

func test_attacking_cannot_be_cancelled_by_movement():
	# game_character.dart: attacks are committed for attackCommitTime.
	sm.request(CharacterStateMachine.State.ATTACKING)
	assert_false(sm.request(CharacterStateMachine.State.WALKING))
	assert_eq(sm.state, CharacterStateMachine.State.ATTACKING)

func test_attacking_can_be_interrupted_by_stun():
	sm.request(CharacterStateMachine.State.ATTACKING)
	assert_true(sm.request(CharacterStateMachine.State.STUNNED))

func test_attacking_can_be_interrupted_by_death():
	sm.request(CharacterStateMachine.State.ATTACKING)
	assert_true(sm.request(CharacterStateMachine.State.DEAD))

func test_animation_name_maps_to_sprite_frames():
	assert_eq(sm.animation_for(CharacterStateMachine.State.IDLE), "idle")
	assert_eq(sm.animation_for(CharacterStateMachine.State.WALKING), "walk")
	assert_eq(sm.animation_for(CharacterStateMachine.State.RUNNING), "run")
	assert_eq(sm.animation_for(CharacterStateMachine.State.JUMPING), "jump")
	assert_eq(sm.animation_for(CharacterStateMachine.State.FALLING), "jump")
	assert_eq(sm.animation_for(CharacterStateMachine.State.LANDING), "landing")
	assert_eq(sm.animation_for(CharacterStateMachine.State.ATTACKING), "attack")
