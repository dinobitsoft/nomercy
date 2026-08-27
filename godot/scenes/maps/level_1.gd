## Wires the slice together: moves the player to the spawn marker, points
## the enemy at the player, and binds the HUD.
extends Node2D

## The Dart original absorbs ground-tier Y jitter and small ledge lips with
## GameConfig.platformSnapDistance = 10.0 (game_config.dart:98), ported here
## as floor_snap_length = 10.0 on the root CharacterBody2D in
## scenes/character/character.tscn. That only smooths the *downhill* case
## (leaving a platform for a slightly lower one without losing floor
## contact for a frame); it adds no step-up assistance, and bots never
## jump (bot_decision.gd has no jump action) -- so a bot standing on a
## *lower* tile still cannot climb onto a tile whose top is a few pixels
## higher. move_and_slide correctly reports that lip as a wall (confirmed
## empirically: is_on_wall() with the neighbouring Platform as the
## collider). That is unchanged original level geometry (level_1.tscn,
## generated from assets/maps/level_1.json by tools/convert_map.py) and is
## not touched here -- ENEMY_SPAWN_OFFSET instead routes around it by
## landing the enemy squarely on the player's own tile (Platform7,
## x=[150,270], top y=933) rather than making it walk there.
##
## The overhead platforms sitting between spawn and the ground tier
## (Platform0 x=[71,191] and Platform1 x=[249,369], both y=[607,637]) are
## the real constraint on ENEMY_SPAWN_OFFSET: BotController's "approach"
## action drives the enemy toward the player's x column at a constant
## ~640px/s (base_speed(dexterity=8)=4 * run_multiplier=160) for the
## *entire* fall, airborne or not. A tall drop gives that convergence time
## to finish while the enemy is still above Platform0/1's shelf, and once
## the residual dx rounds to ~0, BotController._apply()'s toward=signf(dx)
## goes to 0 too -- zero drive, permanently resting on whichever shelf
## corner it clipped, high above the player (confirmed empirically with a
## physics probe sweeping both wide horizontal offsets at the original
## drop height and a range of drop heights at this offset: every large-drop
## candidate converged to the same stuck point on Platform1's edge,
## ~326px above the player, never closer). Spawning below that shelf
## (y=[607,637], so offset.y above -263 keeps the enemy's fall entirely
## below it) removes the trap; the small remaining fall still gives the
## enemy a believable drop onto the player before "approach" has fully
## zeroed out, closing to melee well inside test_enemy_engages_the_player_
## in_melee's 2s window and still satisfying test_enemy_closes_on_the_
## player_over_time (it starts retreating -- kiting away once inside
## optimal_range * 0.7 -- only after that, per ATTACK_RETREAT_SPEED in
## bot_controller.gd).
const ENEMY_SPAWN_OFFSET := Vector2(50, -200)

@onready var _player: Character = $Player
@onready var _enemy: Character = $Enemy
@onready var _hud: Control = $UILayer/HUD
@onready var _spawn: Marker2D = $PlayerSpawn

func _ready() -> void:
	_player.global_position = _spawn.global_position
	_enemy.global_position = _spawn.global_position + ENEMY_SPAWN_OFFSET
	_enemy.get_node("BotController").target = _player
	_hud.bind(_player)
	_enemy.died.connect(_on_enemy_died)
	_player.died.connect(_on_player_died)

func _on_enemy_died() -> void:
	print("Enemy defeated")

func _on_player_died() -> void:
	print("Player defeated")
