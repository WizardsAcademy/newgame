extends Area2D
## Elven arrow fired by Sylvara (Hero 3 of 4).
##
## Collision layers (docs/ARCHITECTURE.md):
##   collision_layer = 8   (player hitbox)
##   collision_mask  = 17  (1 = walls + 16 = enemy hurtbox)
##
## Supports both quick single/fan shots (`piercing = false`) and Sylvara's
## signature charged **Hunter's Great-Arrow** (`piercing = true`, slices
## straight through every enemy in a line!).

@export var speed: float = 390.0
@export var damage: int = 14
@export var max_range: float = 420.0
@export var piercing: bool = false

var owner_player: PlayerBase = null
var _direction: Vector2 = Vector2.RIGHT
var _distance_flown: float = 0.0
var _removed: bool = false
var _hit_enemies: Dictionary = {}


func launch(from_pos: Vector2, direction: Vector2, shooter: PlayerBase, dmg: int, is_piercing: bool = false) -> void:
	global_position = from_pos
	_direction = direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	rotation = _direction.angle()
	owner_player = shooter
	damage = dmg
	piercing = is_piercing
	if piercing:
		scale = Vector2(1.45, 1.45)
		modulate = Color(0.75, 1.25, 0.85, 1.0)


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _removed:
		return

	var step := _direction * speed * delta
	global_position += step
	_distance_flown += step.length()

	if _distance_flown >= max_range:
		_remove()


func _on_area_entered(area: Area2D) -> void:
	if _removed:
		return

	var enemy := _find_enemy(area)
	if enemy == null:
		return
	var eid := enemy.get_instance_id()
	if _hit_enemies.has(eid):
		return
	_hit_enemies[eid] = true

	if owner_player != null and is_instance_valid(owner_player):
		owner_player.deal_combat_damage(
			enemy, damage, false, 10.0 if piercing else 3.0, global_position
		)
	else:
		enemy.take_damage(damage)

	if not piercing:
		_remove()


func _on_body_entered(_body: Node2D) -> void:
	if not _removed:
		_remove()


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

	var parent := get_parent()
	if parent != null:
		var puff := CPUParticles2D.new()
		puff.one_shot = true
		puff.amount = 7
		puff.lifetime = 0.2
		puff.explosiveness = 1.0
		puff.spread = 180.0
		puff.initial_velocity_min = 25.0
		puff.initial_velocity_max = 65.0
		puff.scale_amount_min = 1.0
		puff.scale_amount_max = 2.0
		puff.color = Color(0.45, 0.95, 0.62)
		puff.emitting = false
		parent.add_child(puff)
		puff.global_position = global_position
		puff.emitting = true
		puff.finished.connect(puff.queue_free)

	queue_free()
