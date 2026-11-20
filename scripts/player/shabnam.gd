extends PlayerBase
## Velmira - the Crimson Vampire (Hero 4 of 4, docs/CHARACTERS.md).
##
## Role: High-risk / precision crimson hemomancer (85 HP).
## Signature mechanic: **Crimson Blood Splash (Self-Blood Cost + Tight Leech)**
##   - Attack unleashes a pressurized cone burst of crimson blood (`splash_range`
##     92 px) in front of Velmira — NO boomerang!
##   - **Blood Price (`blood_self_cost = 6`):** Every cast sacrifices **6 HP**
##     of Velmira's own health (down to 1 HP minimum) — spamming into empty air
##     rapidly drains her lifeblood!
##   - **Crimson Leech (`blood_hit_heal = 8`):** Landing the splash on an enemy
##     heals **8 HP** (+2 net HP gain over the 6 HP cost, +2 HP per additional
##     enemy splashed, up to 12 HP max per cast).
##   - Shift Dash: **Crimson Evade** (1.0s CD, **0 damage**, quick dodge step).

@export var splash_range: float = 92.0
@export var splash_half_angle_deg: float = 38.0
@export var blood_self_cost: int = 6
@export var blood_hit_heal: int = 8
@export var blood_extra_target_heal: int = 2
@export var blood_max_heal_per_cast: int = 12


## Animated crimson liquid cone + flying droplets spawned on each Blood Splash!
class BloodSplashVisual extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var max_reach: float = 92.0
	var half_angle: float = deg_to_rad(38.0)
	var progress: float = 0.0
	var droplets: Array[Dictionary] = []

	func setup(aim_dir: Vector2, reach: float, half_deg: float) -> void:
		dir = aim_dir.normalized()
		max_reach = reach
		half_angle = deg_to_rad(half_deg)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in range(14):
			var ang := dir.angle() + rng.randf_range(-half_angle * 0.95, half_angle * 0.95)
			droplets.append({
				"vec": Vector2(cos(ang), sin(ang)),
				"dist": rng.randf_range(0.35, 1.05) * max_reach,
				"r": rng.randf_range(1.6, 3.4),
				"bright": i % 2 == 0,
			})

	func _process(delta: float) -> void:
		progress += delta / 0.22
		if progress >= 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var ease_t := 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 2.2)
		var alpha := 1.0 - pow(clampf(progress, 0.0, 1.0), 1.6)
		var cur_r := lerpf(16.0, max_reach, ease_t)
		var base_ang := dir.angle()

		# Translucent dark-crimson splash cone wave
		var poly := PackedVector2Array([dir * 8.0])
		var steps := 12
		for i in range(steps + 1):
			var a := base_ang + lerpf(-half_angle, half_angle, float(i) / float(steps))
			poly.append(Vector2(cos(a), sin(a)) * cur_r)
		draw_colored_polygon(poly, Color(0.62, 0.04, 0.14, 0.34 * alpha))

		# Bright scarlet leading splash crest arc
		draw_arc(Vector2.ZERO, cur_r, base_ang - half_angle, base_ang + half_angle, 14,
			Color(1.0, 0.20, 0.34, 0.92 * alpha), 2.6)
		draw_arc(Vector2.ZERO, cur_r * 0.72, base_ang - half_angle * 0.8, base_ang + half_angle * 0.8, 12,
			Color(0.88, 0.08, 0.22, 0.70 * alpha), 1.8)

		# Pressurized blood droplets
		for d in droplets:
			var p: Vector2 = (d["vec"] as Vector2) * (float(d["dist"]) * ease_t)
			var rad: float = float(d["r"]) * (1.0 - 0.35 * progress)
			var col := Color(1.0, 0.32, 0.44, 0.95 * alpha) if bool(d["bright"]) \
				else Color(0.55, 0.03, 0.12, 0.92 * alpha)
			draw_circle(p, rad, col)


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_blood_splash_sfx()


func _character_ready() -> void:
	character_id = "velmira"
	character_name = "Velmira"
	dash_speed = 360.0
	dash_deals_damage = false
	dash_phases_enemies = false
	dash_damage = 0
	dash_tint = Color(0.95, 0.18, 0.34, 0.82)


func _get_attack_move_multiplier() -> float:
	return 0.38


func _start_attack() -> void:
	if is_attacking or is_dashing or is_dead:
		return

	_attack_token += 1
	var my_token := _attack_token
	is_attacking = true

	var dir := get_aim_direction()
	if absf(dir.x) > 0.05:
		facing = 1.0 if dir.x > 0.0 else -1.0
		_sync_facing_nodes()

	anim_player.stop()
	anim_player.play("attack")
	punch_sfx.pitch_scale = randf_range(0.95, 1.08)
	punch_sfx.play()

	await get_tree().create_timer(attack_windup).timeout
	if my_token != _attack_token or is_dead:
		return

	# 1. Pay her own lifeblood on EVERY cast (punishes blind spamming!)
	_pay_blood_cost()

	# 2. Unleash the Crimson Blood Splash cone & heal ONLY if enemies are hit!
	_unleash_blood_splash(dir)

	var remaining := maxf(attack_duration - attack_windup, 0.08)
	await get_tree().create_timer(remaining).timeout
	if my_token != _attack_token or is_dead:
		return

	is_attacking = false


func _pay_blood_cost() -> int:
	if is_dead or blood_self_cost <= 0:
		return 0
	# Self-blood sacrifice drops down to 1 HP minimum so spamming leaves Velmira
	# one touch from death without granting enemy-hit invulnerability frames!
	var paid := mini(blood_self_cost, maxi(current_health - 1, 0))
	if paid > 0:
		last_health_change_was_self_cost = true
		current_health -= paid
		health_changed.emit(current_health, max_health)
	return paid


func _unleash_blood_splash(dir: Vector2) -> void:
	var aim := dir.normalized()
	if aim.length() < 0.01:
		aim = Vector2(facing, 0.0)

	var parent := get_parent()
	if parent != null:
		var fx := BloodSplashVisual.new()
		fx.setup(aim, splash_range, splash_half_angle_deg)
		parent.add_child(fx)
		fx.global_position = global_position + aim * 6.0

	var cos_limit := cos(deg_to_rad(splash_half_angle_deg))
	var hits_landed := 0

	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node) or node.get("is_dead") == true:
			continue
		if not (node is Node2D):
			continue
		var enemy := node as Node2D
		var offset := enemy.global_position - global_position
		var dist := offset.length()
		if dist > splash_range:
			continue
		# Point-blank splash (< 22 px) always connects; further out checks cone angle.
		var in_cone := dist <= 22.0 or (offset / maxf(dist, 0.001)).dot(aim) >= cos_limit
		if in_cone:
			hits_landed += 1
			deal_combat_damage(enemy, attack_damage, false, 9.0, enemy.global_position)

	if hits_landed > 0 and not is_dead:
		var total_heal := mini(
			blood_hit_heal + (hits_landed - 1) * blood_extra_target_heal,
			blood_max_heal_per_cast
		)
		heal(total_heal)


func _on_dash_started() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mist := CPUParticles2D.new()
	mist.one_shot = true
	mist.amount = 8
	mist.lifetime = 0.22
	mist.explosiveness = 1.0
	mist.spread = 180.0
	mist.initial_velocity_min = 30.0
	mist.initial_velocity_max = 70.0
	mist.scale_amount_min = 1.5
	mist.scale_amount_max = 2.6
	mist.color = Color(0.92, 0.15, 0.30, 0.85)
	mist.emitting = false
	parent.add_child(mist)
	mist.global_position = global_position
	mist.emitting = true
	mist.finished.connect(mist.queue_free)
