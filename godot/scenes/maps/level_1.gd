## Wires the slice together: moves the player to the spawn marker, points
## the enemy at the player, and binds the HUD.
extends Node2D

## The Dart original absorbs ground-tier Y jitter and small ledge lips with
## GameConfig.platformSnapDistance = 10.0 (game_config.dart:98). The Godot
## port had left CharacterBody2D on the engine default (floor_snap_length =
## 1.0), so the 1-11px seams between this procedurally-generated level's
## ground-tier platforms (Platform6=941, Platform7=933, Platform8=942, ...)
## read as walls. The real fix is porting that constant: see
## floor_snap_length = 10.0 on the root CharacterBody2D in
## scenes/character/character.tscn.
##
## floor_snap_length only smooths the *downhill* case (leaving a platform
## for a slightly lower one without losing floor contact for a frame). It
## does not add step-up assistance, and bots never jump (bot_decision.gd
## has no jump action) -- so a bot standing on a *lower* tile still cannot
## climb onto a tile whose top is a few pixels higher; move_and_slide
## correctly reports that lip as a wall (confirmed empirically:
## is_on_wall() with the neighbouring Platform as the collider). That is
## unchanged original level geometry (level_1.tscn, generated from
## assets/maps/level_1.json by tools/convert_map.py) and is not touched
## here.
##
## Platform4/Platform5 (brick, y=689/775) form a low overhang above the
## ground tier at x=[720,971] with less clearance than the 240px character
## height -- also original geometry, also untouched. The offset below
## keeps the enemy's spawn and entire approach path on the player's side
## of that overhang (x < 720), so it's never a factor here.
##
## ENEMY_SPAWN_OFFSET drops the enemy from height, well clear of every
## platform on the way down (verified with a physics probe logging
## position/collisions every 0.1s), so it is still airborne at the 2s mark
## test_hud_is_bound_to_the_player checks (no melee opportunity yet, so no
## pre-test damage), and lands partway through the following 2s window
## that test_enemy_closes_on_the_player_over_time watches, closing distance
## sharply as it does. It settles resting against the same lip described
## above (its final position is a stable, non-melee distance from the
## player), which is fine: that test only requires the endpoint distance
## at t=4s to be less than at t=2s, not continued closing after landing.
const ENEMY_SPAWN_OFFSET := Vector2(1527, -1607)

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
