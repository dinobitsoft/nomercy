## Plain data describing what a bot can perceive. Built by BotController
## and handed to BotDecision, so the decision logic never touches a node.
class_name WorldSnapshot
extends RefCounted

var distance_to_target: float = 0.0
var health_percent: float = 1.0
var stamina: float = 100.0
var target_is_attacking: bool = false
var target_is_blocking: bool = false
var projectile_incoming: bool = false
var is_grounded: bool = true
var melee_reach: float = 60.0
