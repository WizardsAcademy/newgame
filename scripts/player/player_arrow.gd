extends Area2D
## Versatile player projectile (`PlayerArrow.tscn`) used by Sylvara's Bow & `[R]` Hunter Lock-On!
##
## Collision layers (docs/ARCHITECTURE.md):
##   collision_layer = 8   (player hitbox)
##   collision_mask  = 17  (1 = walls + 16 = enemy hurtbox)
##
## Wall Rule:
##   Hitting any `StaticBody2D` wall or obstacle (via physics raycast OR body overlap)
##   IMMEDIATELY stops and despawns the arrow on the wall — even when `piercing == true`!

const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

@export var speed: float = 390.0
@export var damage: int = 14
@export var max_range: float = 420.0
@export var piercing: bool = false

var direction: Vector2 = Vector2.RIGHT
var knockback_px: float = 6.0
var owner_player: PlayerBase = null
var locked_target: Node2D = null
var homing_strength: float = 0.0

var aoe_radius: float = 0.0
var aoe_damage: int = 0
var explosion_radius: float = 0.0
var explosion_damage: int = 0

var crit_chance: float = 0.0
var crit_mult: float = 2.5
var is_crit: bool = false

var ricochet_count: int = 0
var ricochet_damage_ratio: float = 0.80
var chain_lightning_targets: int = 0
var chain_lightning_ratio: float = 0.60
var longshot_bonus: float = 0.0

var execute_ratio: float = 0.0
var stun_duration: float = 0.0
var slow_factor: float = 0.45
var slow_duration: float = 0.0
var venom_bonus_damage: int = 0
var lifesteal_heal: int = 0
var apply_vampire_stack: bool = false
var puff_color: Color = Color(0.45, 0.95, 0.62)

var _distance_flown: float = 0.0
var _removed: bool = false
var _hit_enemies: Dictionary = {}


func launch(from_pos: Vector2, dir: Vector2, shooter: PlayerBase, dmg: int, is_piercing: bool = false) -> void:
	global_position = from_pos
	direction = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	rotation = direction.angle()
	owner_player = shooter
	damage = dmg
	piercing = is_piercing
	if piercing and scale == Vector2.ONE:
		scale = Vector2(1.35, 1.35)
		modulate = Color(0.75, 1.25, 0.85, 1.0)


func _ready() -> void:
	add_to_group("player_arrows")
	collision_mask |= 1
	rotation = direction.angle()
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _removed:
		return

	if locked_target != null and is_instance_valid(locked_target) and locked_target.get("is_dead") != true:
		var to_lock := locked_target.global_position - global_position
		if to_lock.length() > 2.0:
			direction = direction.lerp(to_lock.normalized(), clampf(16.0 * delta, 0.0, 1.0)).normalized()
			rotation = direction.angle()
	elif homing_strength > 0.0:
		var target := _find_nearest_living_enemy(240.0)
		if target != null:
			var desired := (target.global_position - global_position).normalized()
			direction = direction.lerp(desired, clampf(homing_strength * delta, 0.0, 1.0)).normalized()
			rotation = direction.angle()

	var step := direction * speed * delta
	var next_pos := global_position + step

	# Raycast wall check on layer 1 so fast/piercing arrows ALWAYS stop & despawn on walls!
	var space := get_world_2d().direct_space_state
	if space != null:
		var query := PhysicsRayQueryParameters2D.create(global_position, next_pos, 1)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			var collider: Variant = hit.get("collider")
			if collider is StaticBody2D:
				global_position = hit.get("position", next_pos)
				_remove()
				return

	global_position = next_pos
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
	if longshot_bonus > 0.0:
		var dist_factor := clampf(_distance_flown / 240.0, 0.0, 1.0)
		final_dmg = int(roundf(float(final_dmg) * (1.0 + longshot_bonus * dist_factor)))
	final_dmg += venom_bonus_damage

	if owner_player != null and is_instance_valid(owner_player):
		owner_player.deal_combat_damage(
			enemy, final_dmg, false, 10.0 if piercing else knockback_px, global_position
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
			EnemyStatusScript.apply_slow(enemy, slow_factor, slow_duration)
		if execute_ratio > 0.0 and not enemy.is_in_group("boss") and enemy.get("immovable_dummy") != true and "max_health" in enemy and "current_health" in enemy:
			var mx := int(enemy.max_health)
			if mx > 0 and float(enemy.current_health) / float(mx) <= execute_ratio:
				enemy.take_damage(int(enemy.current_health) + 10)

	var eff_aoe_r := maxf(aoe_radius, explosion_radius)
	var eff_aoe_d := maxi(aoe_damage, explosion_damage)
	if eff_aoe_r > 0.0 and eff_aoe_d > 0:
		_trigger_aoe_burst(enemy, eff_aoe_r, eff_aoe_d)

	if chain_lightning_targets > 0:
		_trigger_chain_lightning(enemy, maxi(int(roundf(float(final_dmg) * chain_lightning_ratio)), 4))

	if ricochet_count > 0:
		var bounce_target := _find_nearest_living_enemy(210.0)
		if bounce_target != null:
			ricochet_count -= 1
			damage = maxi(int(roundf(float(damage) * ricochet_damage_ratio)), 2)
			direction = (bounce_target.global_position - global_position).normalized()
			rotation = direction.angle()
			_distance_flown = 0.0
			return

	if not piercing:
		_remove()


func _trigger_chain_lightning(direct_enemy: Node, arc_dmg: int) -> void:
	var parent := get_parent()
	var hits_done := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if hits_done >= chain_lightning_targets:
			break
		if node == null or not is_instance_valid(node) or node == direct_enemy:
			continue
		if node.get("is_dead") == true or not (node is Node2D):
			continue
		var target_pos: Vector2 = (node as Node2D).global_position
		if target_pos.distance_to(global_position) <= 135.0:
			hits_done += 1
			if parent != null:
				var bolt := Line2D.new()
				bolt.width = 2.0
				bolt.default_color = Color(0.55, 0.96, 1.0, 0.95)
				var mid := (global_position + target_pos) * 0.5 + Vector2(0.0, -9.0)
				bolt.points = PackedVector2Array([global_position, mid, target_pos])
				parent.add_child(bolt)
				var tw := bolt.create_tween()
				tw.tween_property(bolt, "modulate:a", 0.0, 0.15)
				tw.tween_callback(bolt.queue_free)
			if owner_player != null and is_instance_valid(owner_player):
				owner_player.deal_combat_damage(node, arc_dmg, false, 3.0, target_pos)
			else:
				node.take_damage(arc_dmg)


func _trigger_aoe_burst(direct_enemy: Node, rad: float, dmg: int) -> void:
	var parent := get_parent()
	if parent != null:
		var ring := Line2D.new()
		ring.width = 2.4
		ring.default_color = Color(puff_color.r, puff_color.g, puff_color.b, 0.92)
		var pts := PackedVector2Array()
		for i in range(17):
			var a := TAU * float(i) / 16.0
			pts.append(Vector2(cos(a), sin(a)) * rad * 0.45)
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
		if (node as Node2D).global_position.distance_to(global_position) <= rad:
			if owner_player != null and is_instance_valid(owner_player):
				owner_player.deal_combat_damage(node, dmg, false, 4.0, (node as Node2D).global_position)
			else:
				node.take_damage(dmg)


func _on_body_entered(body: Node2D) -> void:
	if _removed:
		return
	if body != null and body.is_in_group("player"):
		return
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
	set_deferred("monitoring", false)

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
