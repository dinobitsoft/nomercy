## Per-class character stats. Ported from
## modules/engine/lib/src/components/character/character_stats.dart
## and the *Stats subclasses in the same directory.
class_name CharacterStats
extends Resource

@export var char_name: String = ""
@export var power: float = 0.0
@export var magic: float = 0.0
@export var dexterity: float = 0.0
@export var intelligence: float = 0.0
@export var weapon_name: String = ""
@export var attack_range: float = 0.0
@export var attack_damage: float = 0.0
@export var max_health: float = 100.0
@export var tint: Color = Color.WHITE
