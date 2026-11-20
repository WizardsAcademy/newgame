extends Area2D
## Boomerang Blood Blade hurled by Shabnam the Vampire (Hero 4 of 4).
##
## Flies outward up to `outbound_range` (or rebounds off a wall!), then
## curves swiftly back into Shabnam's hand - slicing enemies BOTH on the
## way out AND on the way back!

@export var outbound_speed: float = 320.0
@export var return_speed: float = 385.0
@export var outbound_range: float = 175.0
@export var damage: int = 13

var owner_player: PlayerBase = null
var _direction: Vector2 = Vector2.RIGHT
var _distance_out: float = 0.0
var _returning: bool = false
var _return_elapsed: float = 0.0
var _removed: bool = false
var _hit_outbound: Dictionary = {}
var _hit_returning: Dictionary = {}

@onready var visuals: Sprite2D = $Visuals


func launch(from_pos: Vector2, direction: Vector2, thrower: PlayerBase, dmg: int) -> void:
	global_position = from_pos
	_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	owner_player = thrower
	damage = dmg


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _removed:
		return

	if visuals != null:
		visuals.rotation += 18.0 * delta

	if not _returning:
		var step := _direction * outbound_speed * delta
		global_position += step
		_distance_out += step.length()
		if _distance_out >= outbound_range:
			_begin_return()
	else:
		_return_elapsed += delta
		if owner_player == null or not is_instance_valid(owner_player) or owner_player.is_dead or _return_elapsed > 1.6:
			_remove()
			return
		var to_owner := owner_player.global_position - global_position
		if to_owner.length() <= 14.0:
			_remove()
			return
		global_position += to_owner.normalized() * return_speed * delta

	# Poll overlaps so spinning return passes never miss an enemy already inside.
	for area in get_overlapping_areas():
		_try_slice(area)


func _begin_return() -> void:
	if _returning:
		return
	_returning = true
	# Ignore walls on the return trip so the blood blade always flies home.
	collision_mask = 16


func _on_body_entered(_body: Node2D) -> void:
	if not _returning:
		_begin_return()


func _on_area_entered(area: Area2D) -> void:
	_try_slice(area)


func _try_slice(area: Area2D) -> void:
	if _removed:
		return
	var enemy := _find_enemy(area)
	if enemy == null:
		return
	var eid := enemy.get_instance_id()
	var bucket := _hit_returning if _returning else _hit_outbound
	if bucket.has(eid):
		return
	bucket[eid] = true

	if owner_player != null and is_instance_valid(owner_player):
		owner_player.deal_combat_damage(enemy, damage, false, 4.0, global_position)
	else:
		enemy.take_damage(damage)


func _find_enemy(node: Node) -> Node:
	var current: Node = node
	var guard := 4
	while current != null and guard > 0:
		if current.has_method("take_damage") and not current.is_in_group("player"):
			return current
		current = current.get_parent()
		guard -= 1
	return null


func _remove() -> void:
	if _removed:
		return
	_removed = true
	queue_free()
