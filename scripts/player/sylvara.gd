extends PlayerBase
## Sylvara - the Blonde Medieval-Fantasy Elven Huntress (Hero 3 of 4).
##
## Base Kit + Exclusive-Pillar OP Skill Tree:
##   - `solo_top`    : **Windveil Mirage** — 100% projectile dodge for `1.0s` AFTER `Shift` ends!
##   - Pillar 0      : **Emerald Storm** — Multi-arrow volleys, all-piercing shots, Starburst AoE, Zero-Draw Stormbow!
##   - Pillar 1      : **Gale Phantom** — Zephyr Vault heal/haste, Briar Root-Venom, Twin Shadow Great-Arrow, Immortal Windrunner!
##   - Pillar 2      : **Sun Executioner** — 2.5x Heartseeker Crits, Solar Stun Great-Arrows, 30%+ HP Instant Execute!
##   - `solo_bottom` : **Starlight Auto-Barrage** — Auto-aims at nearby enemies and rapid-fires at blazing
##                     attack speed dealing `30%` of her `attack_damage` per shot!

const PLAYER_ARROW_SCENE := preload("res://scenes/player/PlayerArrow.tscn")
const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

@export var charge_threshold: float = 0.35
@export var gust_slow_radius: float = 68.0
@export var gust_slow_factor: float = 0.55
@export var gust_slow_duration: float = 1.8
@export var tailwind_duration: float = 1.4
@export var tailwind_speed_mult: float = 1.28

@export var auto_barrage_enabled: bool = false
@export var auto_barrage_interval: float = 0.11
@export var auto_barrage_range: float = 340.0
@export var auto_barrage_damage_ratio: float = 0.30

var _base_max_hp: int = 100
var _base_atk: int = 15
var _base_move_spd: float = 124.0
var _base_atk_dur: float = 0.38
var _base_charge_thresh: float = 0.35
var _base_dash_cd: float = 1.0
var _base_en_regen: float = 28.0

var _is_drawing: bool = false
var _draw_time: float = 0.0
var _shot_cooldown_left: float = 0.0
var _quick_shot_counter: int = 0
var _tailwind_left: float = 0.0
var _auto_barrage_timer: float = 0.0
var _charge_ring: Line2D = null

var _charged_bonus_dmg: int = 0
var _total_dmg_mult: float = 1.0


func _create_attack_sfx() -> AudioStreamWAV:
	return SFXGenerator.create_bow_sfx()


func _character_ready() -> void:
	character_id = "sylvara"
	character_name = "Sylvara"
	dash_speed = 400.0
	dash_deals_damage = false
	dash_phases_enemies = true
	dash_damage = 0
	dash_tint = Color(0.45, 0.98, 0.62, 0.78)
	_base_max_hp = max_health
	_base_atk = attack_damage
	_base_move_spd = move_speed
	_base_atk_dur = attack_duration
	_base_charge_thresh = charge_threshold
	_base_dash_cd = dash_cooldown
	_base_en_regen = energy_regen_per_sec
	_setup_charge_ring()


func _on_skill_tree_ranks_applied() -> void:
	var p0_1 := skill_rank("p0_t1")
	var p0_2 := skill_rank("p0_t2")
	var p0_4 := skill_rank("p0_t4")
	var p1_1 := skill_rank("p1_t1")
	var p1_4 := skill_rank("p1_t4")
	var p2_2 := skill_rank("p2_t2")
	var p2_4 := skill_rank("p2_t4")

	max_health = _base_max_hp + p1_4 * 22
	current_health = clampi(current_health + (max_health - _base_max_hp), 1, max_health)

	var raw_atk := _base_atk + p0_1 * 5 + p0_2 * 4 + p0_4 * 10 + p2_4 * 12
	_total_dmg_mult = 1.25 if p2_4 > 0 else 1.0
	attack_damage = int(roundf(float(raw_atk) * _total_dmg_mult))
	_charged_bonus_dmg = p2_2 * 14

	move_speed = _base_move_spd + float(p1_1 * 18)
	energy_regen_per_sec = _base_en_regen * (1.0 + 0.20 * float(p1_4))
	dash_cooldown = maxf(0.32, _base_dash_cd * pow(0.88, float(p1_1)))

	if p0_4 > 0:
		var mult := lerpf(0.65, 0.45, float(p0_4 - 1) / 4.0)
		charge_threshold = _base_charge_thresh * mult
		attack_duration = _base_atk_dur * mult
	else:
		charge_threshold = _base_charge_thresh
		attack_duration = _base_atk_dur

	reset_dash_on_kill = (p1_4 > 0)
	auto_barrage_enabled = (skill_rank("solo_bottom") >= 1)


func get_auto_barrage_shot_damage() -> int:
	return maxi(int(roundf(float(attack_damage) * auto_barrage_damage_ratio)), 1)


func _setup_charge_ring() -> void:
	_charge_ring = Line2D.new()
	_charge_ring.name = "ChargeRing"
	_charge_ring.width = 1.6
	_charge_ring.show_behind_parent = true
	_charge_ring.z_index = 0
	_charge_ring.visible = false
	add_child(_charge_ring)


func _get_attack_move_multiplier() -> float:
	return 0.60 if _is_drawing else 0.0


func _get_bonus_speed_multiplier() -> float:
	return tailwind_speed_mult if _tailwind_left > 0.0 else 1.0


func _on_attack_pressed(_event: InputEvent) -> void:
	if is_dead or is_dashing or _is_drawing or _shot_cooldown_left > 0.0:
		return
	_is_drawing = true
	is_attacking = true
	_hurt_anim_left = 0.0
	_draw_time = 0.0
	get_aim_direction()
	anim_player.stop()
	if anim_player.has_animation("bow_draw"):
		anim_player.play("bow_draw")
	else:
		anim_player.play("attack")
		anim_player.pause()
		anim_player.seek(0.0, true)


func _on_attack_released(_event: InputEvent) -> void:
	if not _is_drawing:
		return
	_release_bow_shot()


func _start_attack() -> void:
	if is_dead or is_dashing or _shot_cooldown_left > 0.0:
		return
	_is_drawing = true
	is_attacking = true
	_draw_time = 0.0
	_release_bow_shot()


func _character_physics_process(delta: float) -> void:
	if _shot_cooldown_left > 0.0:
		_shot_cooldown_left = maxf(_shot_cooldown_left - delta, 0.0)
	if _tailwind_left > 0.0:
		_tailwind_left = maxf(_tailwind_left - delta, 0.0)

	# --- ULTIMATE CONVERGED SOLO NODE (`solo_bottom`): STARLIGHT AUTO-BARRAGE ---
	if auto_barrage_enabled and not is_dead:
		_auto_barrage_timer -= delta
		if _auto_barrage_timer <= 0.0:
			var target := _find_nearest_auto_target()
			if target != null:
				_fire_auto_barrage_shot(target)
				_auto_barrage_timer = auto_barrage_interval
			else:
				_auto_barrage_timer = 0.05

	if _is_drawing:
		if is_dead:
			_cancel_draw()
			return
		_draw_time += delta
		if _last_attack_used_mouse:
			get_aim_direction()
		if _draw_time >= charge_threshold * 0.55 and anim_player.has_animation("bow_charge"):
			if anim_player.current_animation != "bow_charge":
				anim_player.play("bow_charge")
		_update_charge_ring()
		if not (_read_input()["attack_held"] as bool) and _draw_time > 0.05:
			_release_bow_shot()
	elif _charge_ring != null and _charge_ring.visible:
		_charge_ring.visible = false


func _find_nearest_auto_target() -> Node2D:
	var best: Node2D = null
	var best_d := auto_barrage_range
	for n in get_tree().get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n) or not (n is Node2D):
			continue
		if n.get("is_dead") == true or not (n as Node2D).visible:
			continue
		var d := global_position.distance_to((n as Node2D).global_position)
		if d <= best_d:
			best_d = d
			best = n as Node2D
	return best


func _fire_auto_barrage_shot(target: Node2D) -> void:
	var dir := (target.global_position - global_position).normalized()
	if dir.length() <= 0.01:
		dir = Vector2(facing, 0.0)
	var dmg := get_auto_barrage_shot_damage()
	var arrow := _spawn_arrow(dir, dmg, skill_rank("p0_t2") > 0, 560.0)
	if arrow != null:
		arrow.modulate = Color(1.0, 0.94, 0.42, 0.95)
		arrow.scale = Vector2(1.05, 1.05)
		arrow.homing_strength = 9.0
		arrow.puff_color = Color(1.0, 0.90, 0.36)


func _update_charge_ring() -> void:
	if _charge_ring == null:
		return
	_charge_ring.visible = true
	var ratio := clampf(_draw_time / maxf(charge_threshold, 0.05), 0.0, 1.0)
	var r := lerpf(16.0, 11.0, ratio)
	var segs := 20
	var max_seg := maxi(int(roundf(float(segs) * ratio)), 2)
	var pts := PackedVector2Array()
	for i in max_seg + 1:
		var a := -PI * 0.5 + TAU * ratio * (float(i) / float(max_seg))
		pts.append(Vector2(cos(a), sin(a)) * r + Vector2(0.0, 6.0))
	_charge_ring.points = pts
	_charge_ring.default_color = Color(0.80, 1.0, 0.58, 0.95) if ratio >= 1.0 \
		else Color(0.38, 0.94, 0.58, 0.58)


func _release_bow_shot() -> void:
	var charged := _draw_time >= charge_threshold
	_is_drawing = false
	if _charge_ring != null:
		_charge_ring.visible = false

	var dir := get_aim_direction()
	if absf(dir.x) > 0.05:
		facing = 1.0 if dir.x > 0.0 else -1.0
		_sync_facing_nodes()

	punch_sfx.pitch_scale = 0.82 if charged else 1.08
	punch_sfx.play()

	if anim_player.has_animation("bow_release"):
		anim_player.play("bow_release")
	else:
		anim_player.play("attack")
		anim_player.seek(0.10, true)

	var all_pierce := skill_rank("p0_t2") > 0
	var volley_rk := skill_rank("p0_t1")
	var twin_rk := skill_rank("p1_t3")

	if charged:
		var great_dmg := int(roundf(float(attack_damage) * 2.0)) + _charged_bonus_dmg
		_spawn_arrow(dir, great_dmg, true, 495.0, true)
		if volley_rk > 0:
			_spawn_arrow(dir.rotated(deg_to_rad(-8.0)), int(roundf(float(great_dmg) * 0.65)), true, 470.0, true)
			_spawn_arrow(dir.rotated(deg_to_rad(8.0)), int(roundf(float(great_dmg) * 0.65)), true, 470.0, true)
		ScreenShake.shake(3.0, 0.14)
	else:
		_quick_shot_counter += 1
		_spawn_arrow(dir, attack_damage, all_pierce, 405.0, false)
		if volley_rk > 0 or (_quick_shot_counter % 4 == 0):
			var side_dmg := attack_damage if volley_rk > 0 else maxi(int(attack_damage * 0.75), 1)
			_spawn_arrow(dir.rotated(deg_to_rad(-9.0)), side_dmg, all_pierce, 390.0, false)
			_spawn_arrow(dir.rotated(deg_to_rad(9.0)), side_dmg, all_pierce, 390.0, false)
			if volley_rk >= 3:
				_spawn_arrow(dir.rotated(deg_to_rad(-18.0)), maxi(int(side_dmg * 0.8), 1), all_pierce, 380.0, false)
				_spawn_arrow(dir.rotated(deg_to_rad(18.0)), maxi(int(side_dmg * 0.8), 1), all_pierce, 380.0, false)
		else:
			ScreenShake.shake(1.2, 0.07)

	# Pillar 1 Tier 3: Twin Phantom Shadow Great-Arrow!
	if twin_rk > 0:
		var ph_dmg := maxi(int(roundf(float(attack_damage) * (0.50 + 0.10 * float(twin_rk)))), 1)
		var ph := _spawn_arrow(dir.rotated(deg_to_rad(2.5)), ph_dmg, true, 520.0, false)
		if ph != null:
			ph.modulate = Color(0.55, 1.0, 0.92, 0.82)

	_shot_cooldown_left = maxf(attack_duration * 0.85, 0.08)
	_attack_token += 1
	var my_token := _attack_token
	await get_tree().create_timer(0.12).timeout
	if my_token == _attack_token:
		is_attacking = false


func _spawn_arrow(dir: Vector2, dmg: int, is_piercing: bool, arrow_speed: float, is_charged_great: bool = false) -> Area2D:
	var parent := get_parent()
	if parent == null:
		return null
	var arrow: Area2D = PLAYER_ARROW_SCENE.instantiate()
	arrow.speed = arrow_speed

	var p0_3 := skill_rank("p0_t3")
	if p0_3 > 0:
		arrow.aoe_radius = 56.0
		arrow.aoe_damage = maxi(int(roundf(float(dmg) * (0.43 + 0.12 * float(p0_3)))), 2)

	var p1_2 := skill_rank("p1_t2")
	if p1_2 > 0:
		arrow.slow_duration = 2.4
		arrow.venom_bonus_damage = 7 + 5 * p1_2

	var p2_1 := skill_rank("p2_t1")
	if p2_1 > 0:
		arrow.crit_chance = clampf(0.25 + 0.10 * float(p2_1), 0.0, 0.90)
		arrow.crit_mult = 2.5

	if is_charged_great and skill_rank("p2_t2") > 0:
		arrow.stun_duration = 0.80

	var p2_3 := skill_rank("p2_t3")
	if p2_3 > 0:
		arrow.execute_ratio = 0.26 + 0.04 * float(p2_3)

	parent.add_child(arrow)
	var muzzle := global_position + dir.normalized() * 14.0 + Vector2(0.0, -2.0)
	arrow.launch(muzzle, dir, self, dmg, is_piercing)
	return arrow


func _cancel_draw() -> void:
	_is_drawing = false
	is_attacking = false
	if _charge_ring != null:
		_charge_ring.visible = false


func _on_dash_started() -> void:
	_cancel_draw()
	_tailwind_left = tailwind_duration
	if skill_rank("p1_t1") > 0:
		heal(12)
	_spawn_sylvan_gust(global_position)


func _spawn_sylvan_gust(origin: Vector2) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and is_instance_valid(node) and node.get("is_dead") != true:
			if (node as Node2D).global_position.distance_to(origin) <= gust_slow_radius:
				EnemyStatusScript.apply_slow(node, gust_slow_factor, gust_slow_duration)

	var parent := get_parent()
	if parent == null:
		return

	var vortex := Line2D.new()
	vortex.width = 2.0
	vortex.default_color = Color(0.45, 0.98, 0.62, 0.85)
	var pts := PackedVector2Array()
	for i in range(25):
		var t := float(i) / 24.0
		var r := lerpf(4.0, 22.0, t)
		var a := t * TAU * 1.6
		pts.append(Vector2(cos(a), sin(a)) * r)
	vortex.points = pts
	parent.add_child(vortex)
	vortex.global_position = origin
	var tw := vortex.create_tween()
	tw.set_parallel(true)
	tw.tween_property(vortex, "rotation", 2.4, 0.32)
	tw.tween_property(vortex, "scale", Vector2(1.6, 1.6), 0.32)
	tw.tween_property(vortex, "modulate:a", 0.0, 0.32)
	tw.chain().tween_callback(vortex.queue_free)

	var leaves := CPUParticles2D.new()
	leaves.one_shot = true
	leaves.amount = 10
	leaves.lifetime = 0.38
	leaves.explosiveness = 0.95
	leaves.spread = 180.0
	leaves.initial_velocity_min = 24.0
	leaves.initial_velocity_max = 62.0
	leaves.gravity = Vector2(0, 12)
	leaves.scale_amount_min = 1.6
	leaves.scale_amount_max = 2.8
	leaves.color = Color(0.56, 1.0, 0.66, 0.90)
	leaves.emitting = false
	parent.add_child(leaves)
	leaves.global_position = origin
	leaves.emitting = true
	leaves.finished.connect(leaves.queue_free)
