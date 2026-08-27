## A solid platform. Replaces the five Flame classes tiled_platform,
## enhanced_platform, tiled_ground_component, platform_factory and
## game_platform (~830 LOC) with one scene; Godot's texture_repeat does
## the seamless tiling those classes hand-rolled.
class_name Platform
extends StaticBody2D

enum Kind { BRICK, GROUND, STONE }

const TEXTURES := {
	Kind.BRICK: "res://assets/images/brick_tile.png",
	## Cropped from assets/images/ground_tile.png to the tuft's opaque bounds
	## (x 330..1214, y 286..806 of 1536x1024). The source carries ~40% empty
	## margin, which tiles as a visible gap between tufts; cropping makes
	## adjacent tiles butt together into a continuous grass line.
	Kind.GROUND: "res://textures/grass_tile.png",
	Kind.STONE: "res://assets/images/stone.png",
}

## ground_tile.png is a grass tuft painted on an opaque grey field, not a
## tileable soil texture (ground.png is byte-identical). Stretched over a tall
## strip it renders 600px of that grey, which reads as empty background —
## the ground looked like floating tufts over a void.
##
## So the texture is used only as a SURFACE BAND along the top edge, and the
## body beneath is filled with solid earth. Thin platforms (the 30px ones the
## converter emits) are shorter than the band and behave exactly as before.
## Thick ground strips render as two layers, bottom-up: brick bedrock, then a
## grass surface band that characters walk on. Thin platforms (the 30px ones
## the converter emits) are shorter than the band and stay single-layer.
const SURFACE_BAND := 30.0
const BEDROCK_TEX := preload("res://assets/images/brick_tile.png")

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
	var tex: Texture2D = load(TEXTURES[kind])
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.centered = false

	# Scale the WHOLE texture down to the strip's height, then repeat it
	# horizontally — matching Dart's tiled_ground_component.dart:137, which uses
	# the full image as its source rect and draws it into fixed-size tiles.
	#
	# Cropping instead (region_rect = Rect2(ZERO, size)) samples the top-left
	# corner of the source, which for ground_tile.png (1536x1024, grass tuft
	# centred) is flat grey — the ground rendered invisible on device.
	var tex_h := float(tex.get_height())
	var band := minf(size.y, SURFACE_BAND)
	var fit := band / tex_h if tex_h > 0.0 else 1.0
	_sprite.scale = Vector2(fit, fit)
	# Region is expressed in texture space; scaling maps it back onto `size.x`.
	_sprite.region_rect = Rect2(0.0, 0.0, size.x / fit, tex_h)
	queue_redraw()

	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_shape.position = size / 2.0

## Bedrock layer beneath the grass band. A CanvasItem draws itself before its
## children, so the grass Sprite2D renders on top of this.
func _draw() -> void:
	if size.y <= SURFACE_BAND:
		return
	var body := Rect2(0.0, SURFACE_BAND, size.x, size.y - SURFACE_BAND)
	draw_texture_rect(BEDROCK_TEX, body, true)
