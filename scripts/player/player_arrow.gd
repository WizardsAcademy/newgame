extends Area2D
## Versatile player projectile (`PlayerArrow.tscn`) used by Sylvara's Bow & OP Skill Tree abilities!
##
## Collision layers (docs/ARCHITECTURE.md):
##   collision_layer = 8   (player hitbox)
##   collision_mask  = 17  (1 = walls + 16 = enemy hurtbox)

const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

@export var speed: float = 390.0
@export var damage: int = 14
@export var max_range: float = 420.0
@export var piercing: bool = false

var owner_player: PlayerBase = null
var aoe_radius: float = 0.0
var aoe_damage: int = 0
var crit_chance: float = 0.0
var crit_mult: float = 2.5
var execute_ratio: float = 0.0
var stun_duration: float = 0.0
var slow_duration: float = 0.0
var venom_bonus_damage: int = 0
var lifesteal_heal: int = 0
var apply_vampire_stack: bool = false
var homing_strength: float = 0.0
var puff_color: Color = Color(0.45, 0.95, 0.62)

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
	if piercing and scale == Vector2.ONE:
		scale = Vector2(1.45, 1.45)
		modulate = Color(0.75, 1.25, 0.85, 1.0)


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _removed:
		return

	if homing_strength > 0.0:
		var target := _find_nearest_living_enemy(260.0)
		if target != null:
			var desired := (target.global_position - global_position).normalized()
			_direction = _direction.lerp(desired, clampf(homing_strength * delta, 0.0, 1.0)).normalized()
			rotation = _direction.angle()

	var step := _direction * speed * delta
	global_position += step
	_distance_flown += step.length()

	if _distance_flown >= max_range:
		_remove()


func _find_nearest_living_enemy(max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n) or not (n is Node2D):
			continue
		if n.get("is_dead") == true or not (n as Node2D).visible:
			continue
		var eid := n.get_instance_id()
		if _hit_enemies.has(eid):
			continue
		var d := global_position.distance_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n as Node2D
	return best


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

	var final_dmg := damage
	if crit_chance > 0.0 and randf() < crit_chance:
		final_dmg = int(roundf(float(final_dmg) * crit_mult))
	final_dmg += venom_bonus_damage

	if owner_player != null and is_instance_valid(owner_player):
		owner_player.deal_combat_damage(
			enemy, final_dmg, false, 10.0 if piercing else 3.0, global_position
		)
		if lifesteal_heal > 0:
			owner_player.heal(lifesteal_heal)
		if apply_vampire_stack and enemy != null and is_instance_valid(enemy) and enemy.get("is_dead") != true:
			EnemyStatusScript.add_vampire_fang_stack(enemy, owner_player)
	else:
		enemy.take_damage(final_dmg)

	if enemy != null and is_instance_valid(enemy) and enemy.get("is_dead") != true:
		if stun_duration > 0.0:
			EnemyStatusScript.apply_stun(enemy, stun_duration)
		if slow_duration > 0.0:
			EnemyStatusScript.apply_slow(enemy, 0.45, slow_duration)
		if execute_ratio > 0.0 and enemy.get("immovable_dummy") != true and "max_health" in enemy and "current_health" in enemy:
			var mx := int(enemy.max_health)
			if mx > 0 and mx <= 400 and float(enemy.current_health) / float(mx) <= execute_ratio:
				enemy.take_damage(int(enemy.current_health) + 1)

	if aoe_radius > 0.0 and aoe_damage > 0:
		_trigger_aoe_burst(enemy)

	if not piercing:
		_remove()


func _trigger_aoe_burst(direct_enemy: Node) -> void:
	var parent := get_parent()
	if parent != null:
		var ring := Line2D.new()
		ring.width = 2.4
		ring.default_color = Color(puff_color.r, puff_color.g, puff_color.b, 0.92)
		var pts := PackedVector2Array()
		for i in range(17):
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(cos(a), sin(a)) * aoe_radius * 0.45)
		ring.points = pts
		parent.add_child(ring)
		ring.global_position = global_position
		var tw := ring.create_tween()
		tw.set_parallel(true)
		tw.tween_property(ring, "scale", Vector2(2.1, 2.1), 0.18)
		tw.tween_property(ring, "modulate:a", 0.0, 0.18)
		tw.chain().tween_callback(ring.queue_free)

	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node) or node == direct_enemy:
			continue
		if node.get("is_dead") == true or not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_to(global_position) <= aoe_radius:
			if owner_player != null and is_instance_valid(owner_player):
				owner_player.deal_combat_damage(node, aoe_damage, false, 4.0, (node as Node2D).global_position)
			else:
				node.take_damage(aoe_damage)


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
		puff.color = puff_color
		puff.emitting = false
		parent.add_child(puff)
		puff.global_position = global_position
		puff.emitting = true
		puff.finished.connect(puff.queue_free)

	queue_free()
