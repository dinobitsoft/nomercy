## A solid platform. Replaces the five Flame classes tiled_platform,
## enhanced_platform, tiled_ground_component, platform_factory and
## game_platform (~830 LOC) with one scene; Godot's texture_repeat does
## the seamless tiling those classes hand-rolled.
class_name Platform
extends StaticBody2D

enum Kind { BRICK, GROUND, STONE }

const TEXTURES := {
	Kind.BRICK: "res://assets/images/brick_tile.png",
	Kind.GROUND: "res://assets/images/ground_tile.png",
	Kind.STONE: "res://assets/images/stone.png",
}

@export var kind: Kind = Kind.BRICK:
	set(value):
		kind = value
		_apply()

@export var size: Vector2 = Vector2(120, 30):
	set(value):
		size = value
		_apply()

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_apply()

func _apply() -> void:
	if not is_node_ready():
		return
	_sprite.texture = load(TEXTURES[kind])
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(Vector2.ZERO, size)
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.centered = false
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0
