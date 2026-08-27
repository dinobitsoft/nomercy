extends GutTest

const CHARACTER := preload("res://scenes/character/character.tscn")

var peer: ENetMultiplayerPeer

func after_each():
	if peer != null:
		peer.close()
		peer = null
	get_tree().get_multiplayer().multiplayer_peer = null

func test_without_a_peer_every_character_is_its_own_authority():
	var c: Character = CHARACTER.instantiate()
	add_child_autofree(c)
	await wait_frames(2)
	assert_true(c.is_authority(),
		"Single-player must behave as fully authoritative")

func test_a_server_peer_can_be_created():
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(28970, 2)
	assert_eq(err, OK, "Failed to create an ENet server on port 28970")

func test_the_server_holds_authority_over_a_spawned_character():
	peer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_server(28971, 2), OK)
	get_tree().get_multiplayer().multiplayer_peer = peer
	await wait_frames(2)

	var c: Character = CHARACTER.instantiate()
	add_child_autofree(c)
	await wait_frames(2)

	# Unique ID 1 is always the server.
	assert_eq(get_tree().get_multiplayer().get_unique_id(), 1)
	assert_true(c.is_authority(),
		"The server must hold authority over characters it spawns")

func test_a_non_authoritative_character_refuses_state_mutation():
	peer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_server(28972, 2), OK)
	get_tree().get_multiplayer().multiplayer_peer = peer
	await wait_frames(2)

	var c: Character = CHARACTER.instantiate()
	add_child_autofree(c)
	await wait_frames(2)

	# Hand authority to a peer that is not us.
	c.set_multiplayer_authority(999)
	assert_false(c.is_authority())

	var before: float = c.health
	c.apply_damage(50.0)
	assert_almost_eq(c.health, before, 1e-6,
		"A non-authority must not mutate health locally")

	var stamina_before: float = c.stamina
	c.try_jump()
	assert_almost_eq(c.stamina, stamina_before, 1e-6,
		"A non-authority must not spend stamina locally")

func test_synchronizer_is_present_on_the_character_scene():
	var c: Character = CHARACTER.instantiate()
	add_child_autofree(c)
	await wait_frames(2)
	assert_not_null(c.get_node_or_null("MultiplayerSynchronizer"),
		"Character must carry a MultiplayerSynchronizer from day one")
