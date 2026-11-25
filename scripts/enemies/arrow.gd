extends Area2D
## Enemy Projectile (`Arrow.tscn`) — fired by Skeleton Archers & Region 2/3 Ranged Foes/Bosses.
##
## Guarantees:
##   1. Collides with solid walls/obstacles (`StaticBody2D` on layer 1) via both
##      `body_entered` AND per-frame raycast sweep so fast projectiles NEVER tunnel
##      through walls — hitting any wall immediately despawns the projectile!
##   2. Respects Sylvara's `is_dodging_projectiles()` (`1.0s` post-Shift dodge).

signal arrow_removed

@export var speed: float = 240.0
@export var damage: int = 5
@export var max_range: float = 420.0

var slow_player_duration: float = 0.0
var puff_color: Color = Color(0.85, 0.8, 0.65)

var _direction: Vector2 = Vector2.RIGHT
var _distance_flown: float = 0.0
var _has_hit: bool = false


func launch(from_position: Vector2, direction: Vector2) -> void:
	global_position = from_position
	_direction = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	rotation = _direction.angle()


func _ready() -> void:
	collision_mask = collision_mask | 1
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _hits_solid_wall(from_pt: Vector2, to_pt: Vector2) -> Dictionary:
	var w2d := get_world_2d()
	if w2d == null:
		return {}
	var space := w2d.direct_space_state
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters2D.create(from_pt, to_pt, 1)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var res: Dictionary = space.intersect_ray(query)
	if not res.is_empty():
		var collider: Variant = res.get("collider")
		if collider is StaticBody2D:
			return res
	return {}


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	for b in get_overlapping_bodies():
		if b is StaticBody2D:
			_has_hit = true
			_remove()
			return

	var old_pos := global_position
	var step: Vector2 = _direction * speed * delta
	var next_pos := old_pos + step

	var wall_hit := _hits_solid_wall(old_pos, next_pos)
	if not wall_hit.is_empty():
		global_position = wall_hit.get("position", next_pos)
		_has_hit = true
		_remove()
		return

	global_position = next_pos
	_distance_flown += step.length()

	if _distance_flown >= max_range:
		_remove()


func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return

	var current: Node = area
	var guard := 4
	while current != null and guard > 0:
		if current.has_method("is_dodging_projectiles") and bool(current.is_dodging_projectiles()):
			if current.has_method("on_projectile_dodged"):
				current.on_projectile_dodged(global_position)
			return
		if current.has_method("take_damage") and not current.is_in_group("enemies"):
			_has_hit = true
			current.take_damage(damage, global_position, true)
			if slow_player_duration > 0.0 and current.has_method("apply_external_slow"):
				current.apply_external_slow(slow_player_duration)
			_remove()
			return
		current = current.get_parent()
		guard -= 1


func _on_body_entered(body: Node2D) -> void:
	if not _has_hit and body is StaticBody2D:
		_has_hit = true
		_remove()


func _remove() -> void:
	arrow_removed.emit()
	var parent := get_parent()
	if parent != null:
		var puff := CPUParticles2D.new()
		puff.one_shot = true
		puff.amount = 6
		puff.lifetime = 0.2
		puff.explosiveness = 1.0
		puff.spread = 180.0
		puff.initial_velocity_min = 30.0
		puff.initial_velocity_max = 70.0
		puff.scale_amount_min = 1.0
		puff.scale_amount_max = 2.0
		puff.color = puff_color
		puff.emitting = false
		parent.add_child(puff)
		puff.global_position = global_position
		puff.emitting = true
		puff.finished.connect(puff.queue_free)

	queue_free()
