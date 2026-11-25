extends PlayerBase
## Sylvara - the Blonde Medieval-Fantasy Elven Huntress (Hero 3 of 4).
##
## Unique Skill Tree & `[R]` Hunter's Rapid Lock-On:
##   - `solo_top`    : **Windveil Mirage** — 100% projectile dodge for `1.0s` AFTER `Shift` ends (Sylvara ONLY)!
##   - Pillar 0      : **Tempest Volley** — Multi-arrow fan, all-piercing shots, Starburst AoE, Zero-Draw Stormbow!
##   - Pillar 1      : **Trap & Venom** — Bramble Snare Trap on Shift, Venomvine slow, Ricochet Wind-Shot!
##   - Pillar 2      : **Storm Sniper** — 2.5x Eagle-Eye Crits, Chain-Lightning arrows, Heartseeker Execute!
##   - `solo_bottom` : **`[R]` Hunter's Rapid Lock-On** — Shortened range (`210px`); pressing `R` selects
##                     **1 enemy** and rapidly auto-spams homing arrows at that target!

const PLAYER_ARROW_SCENE := preload("res://scenes/player/PlayerArrow.tscn")
const EnemyStatusScript := preload("res://scripts/enemies/enemy_status.gd")

@export var charge_threshold: float = 0.35
@export var gust_slow_radius: float = 68.0
@export var gust_slow_factor: float = 0.55
@export var gust_slow_duration: float = 1.8
@export var tailwind_duration: float = 1.4
@export var tailwind_speed_mult: float = 1.28

## Shortened `[R]` Lock-On range (`range auto arrow elf ro kam kon va bokonesh ability R`)!
@export var auto_barrage_range: float = 210.0
@export var auto_barrage_interval: float = 0.09
@export var auto_barrage_damage_ratio: float = 0.30
@export var ult_lock_duration: float = 4.0

var locked_ult_target: Node2D = null

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
var _reticle_fx: SylvaraLockReticleFX = null

var _charged_bonus_dmg: int = 0
var _total_dmg_mult: float = 1.0


class SylvaraLockReticleFX extends Node2D:
	var target_node: Node2D = null
	var anim_t: float = 0.0

	func _process(delta: float) -> void:
		anim_t += delta
		if target_node != null and is_instance_valid(target_node) and target_node.get("is_dead") != true:
			global_position = target_node.global_position + Vector2(0.0, -10.0)
			visible = true
			queue_redraw()
		else:
			visible = false

	func _draw() -> void:
		var r := 15.0 + 2.0 * sin(anim_t * 12.0)
		var col := Color(0.32, 1.0, 0.58, 0.96)
		var gold := Color(1.0, 0.88, 0.34, 0.96)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, col, 2.0)
		for i in range(4):
			var a := anim_t * 4.2 + float(i) * (PI * 0.5)
			var dir := Vector2(cos(a), sin(a))
			draw_line(dir * (r - 4.0), dir * (r + 5.0), gold, 2.2)


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
	ult_cooldown = 16.0

	_base_max_hp = max_health
	_base_atk = attack_damage
	_base_move_spd = move_speed
	_base_atk_dur = attack_duration
	_base_charge_thresh = charge_threshold
	_base_dash_cd = dash_cooldown
	_base_en_regen = energy_regen_per_sec
	_setup_charge_ring()

	_reticle_fx = SylvaraLockReticleFX.new()
	_reticle_fx.name = "HunterLockReticle"
	_reticle_fx.top_level = true
	_reticle_fx.z_index = 25
	_reticle_fx.visible = false
	add_child(_reticle_fx)


func _on_skill_tree_ranks_applied() -> void:
	# Skill 1 (`solo_top`): Sylvara EXCLUSIVELY gets 1.0s 100% projectile dodge after Shift!
	post_dash_dodge_duration = 1.0 if skill_rank("solo_top") >= 1 else 0.0
	post_dash_invincible_duration = 0.0

	var p0_1 := skill_rank("p0_t1")
	var p0_2 := skill_rank("p0_t2")
	var p0_4 := skill_rank("p0_t4")
	var p1_1 := skill_rank("p1_t1")
	var p1_4 := skill_rank("p1_t4")
	var p2_2 := skill_rank("p2_t2")
	var p2_4 := skill_rank("p2_t4")

	max_health = _base_max_hp + p1_4 * 42
	current_health = clampi(current_health + (max_health - _base_max_hp), 1, max_health)

	var raw_atk := _base_atk + p0_1 * 10 + p0_2 * 9 + p0_4 * 22 + p2_4 * 24
	_total_dmg_mult = 1.30 if p2_4 > 0 else 1.0
	attack_damage = int(roundf(float(raw_atk) * _total_dmg_mult))
	_charged_bonus_dmg = p2_2 * 18

	move_speed = _base_move_spd + float(p1_1 * 18)
	energy_regen_per_sec = _base_en_regen * (1.0 + 0.25 * float(p1_4))
	dash_cooldown = maxf(0.32, _base_dash_cd * pow(0.88, float(p1_1)))

	if p0_4 > 0:
		var mult := lerpf(0.60, 0.42, float(p0_4 - 1) / 4.0)
		charge_threshold = _base_charge_thresh * mult
		attack_duration = _base_atk_dur * mult
	else:
		charge_threshold = _base_charge_thresh
		attack_duration = _base_atk_dur

	reset_dash_on_kill = (p1_4 > 0)
	kill_heal_flat = 10 if p1_4 > 0 else 0


func _activate_ultimate() -> bool:
	var chosen := _select_lock_on_enemy()
	if chosen == null:
		return false
	locked_ult_target = chosen
	ult_active = true
	ult_active_left = ult_lock_duration
	ult_cooldown_left = ult_cooldown
	_auto_barrage_timer = 0.0
	if _reticle_fx != null:
		_reticle_fx.target_node = locked_ult_target
	_fire_auto_barrage_shot(locked_ult_target)
	return true


func _select_lock_on_enemy() -> Node2D:
	var mouse_pos := get_global_mouse_position()
	var best_near_mouse: Node2D = null
	var best_mouse_d := 96.0
	var nearest_in_range: Node2D = null
	var nearest_d := auto_barrage_range

	for n in get_tree().get_nodes_in_group("enemies"):
		if n == null or not is_instance_valid(n) or not (n is Node2D):
			continue
		if n.get("is_dead") == true or not (n as Node2D).visible:
			continue
		var epos := (n as Node2D).global_position
		var dist_self := global_position.distance_to(epos)
		if dist_self > auto_barrage_range:
			continue
		if dist_self < nearest_d:
			nearest_d = dist_self
			nearest_in_range = n as Node2D
		var dist_mouse := mouse_pos.distance_to(epos)
		if dist_mouse < best_mouse_d:
			best_mouse_d = dist_mouse
			best_near_mouse = n as Node2D

	return best_near_mouse if best_near_mouse != null else nearest_in_range


func get_ability_hud_info() -> Array[Dictionary]:
	return [
		{"key": "LMB", "title": "Bow", "icon_idx": 1, "cd_left": _shot_cooldown_left, "cd_max": maxf(attack_duration, 0.1), "unlocked": true, "active": _is_drawing},
		{"key": "SHIFT", "title": "Vault", "icon_idx": 5, "cd_left": dash_cooldown_left, "cd_max": maxf(dash_cooldown, 0.1), "unlocked": true, "active": is_dashing or post_dash_dodge_left > 0.0},
		{"key": "R", "title": "Lock-On", "icon_idx": 14, "cd_left": ult_cooldown_left, "cd_max": maxf(ult_cooldown, 0.1), "unlocked": is_ultimate_unlocked(), "active": ult_active},
	]


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
	var base_m := super._get_bonus_speed_multiplier()
	return base_m * (tailwind_speed_mult if _tailwind_left > 0.0 else 1.0)


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

	# `[R]` Hunter's Rapid Lock-On: auto-spams homing arrows at the 1 selected target!
	if ult_active:
		ult_active_left = maxf(ult_active_left - delta, 0.0)
		var valid_target := (
			locked_ult_target != null
			and is_instance_valid(locked_ult_target)
			and locked_ult_target.get("is_dead") != true
			and locked_ult_target.visible
		)
		if ult_active_left <= 0.0 or not valid_target or is_dead:
			ult_active = false
			locked_ult_target = null
			if _reticle_fx != null:
				_reticle_fx.target_node = null
			ultimate_state_changed.emit(false, ult_cooldown_left, ult_cooldown)
		else:
			_auto_barrage_timer -= delta
			if _auto_barrage_timer <= 0.0:
				_auto_barrage_timer = auto_barrage_interval
				_fire_auto_barrage_shot(locked_ult_target)

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


func _fire_auto_barrage_shot(target: Node2D) -> void:
	var dir := (target.global_position - global_position).normalized()
	if dir.length() <= 0.01:
		dir = Vector2(facing, 0.0)
	var dmg := get_auto_barrage_shot_damage()
	var arrow := _spawn_arrow(dir, dmg, skill_rank("p0_t2") > 0, 520.0)
	if arrow != null:
		arrow.modulate = Color(1.0, 0.94, 0.42, 0.95)
		arrow.scale = Vector2(1.05, 1.05)
		arrow.locked_target = target
		arrow.homing_strength = 12.0
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

	if charged:
		var great_dmg := int(roundf(float(attack_damage) * 2.0)) + _charged_bonus_dmg
		_spawn_arrow(dir, great_dmg, true, 495.0, true)
		if volley_rk > 0:
			_spawn_arrow(dir.rotated(deg_to_rad(-8.0)), int(roundf(float(great_dmg) * 0.75)), true, 470.0, true)
			_spawn_arrow(dir.rotated(deg_to_rad(8.0)), int(roundf(float(great_dmg) * 0.75)), true, 470.0, true)
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

	_shot_cooldown_left = 0.03 if WitchCauldronProgression.wizard_cheat_active else maxf(attack_duration * 0.85, 0.08)
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
		arrow.aoe_radius = 58.0
		arrow.aoe_damage = maxi(int(roundf(float(dmg) * (0.50 + 0.15 * float(p0_3)))), 4)

	var p1_2 := skill_rank("p1_t2")
	if p1_2 > 0:
		arrow.slow_duration = 2.4
		arrow.venom_bonus_damage = 16 + 12 * p1_2

	var p1_3 := skill_rank("p1_t3")
	if p1_3 > 0:
		arrow.ricochet_count = 1
		arrow.ricochet_damage_ratio = 0.70 + 0.10 * float(p1_3)

	var p2_1 := skill_rank("p2_t1")
	if p2_1 > 0:
		arrow.crit_chance = clampf(0.25 + 0.10 * float(p2_1), 0.0, 0.90)
		arrow.crit_mult = 2.5

	var p2_2 := skill_rank("p2_t2")
	if p2_2 > 0:
		arrow.chain_lightning_targets = 2
		arrow.chain_lightning_ratio = 0.48 + 0.12 * float(p2_2)
		if is_charged_great:
			arrow.stun_duration = 0.85

	var p2_3 := skill_rank("p2_t3")
	if p2_3 > 0:
		arrow.longshot_bonus = 0.45
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
	var trap_rk := skill_rank("p1_t1")
	if trap_rk > 0:
		_spawn_bramble_trap(_dash_start_pos, 26 + 16 * trap_rk)
	_spawn_sylvan_gust(global_position)


func _spawn_bramble_trap(pos: Vector2, dmg: int) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var trap := Node2D.new()
	trap.name = "BrambleTrap"
	parent.add_child(trap)
	trap.global_position = pos

	var ring := Line2D.new()
	ring.width = 2.2
	ring.default_color = Color(0.28, 0.92, 0.48, 0.90)
	var pts := PackedVector2Array()
	for i in range(17):
		var a := TAU * float(i) / 16.0
		var r := 16.0 if (i % 2 == 0) else 10.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	ring.points = pts
	trap.add_child(ring)

	for _step in range(14):
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(trap) or is_dead:
			if is_instance_valid(trap):
				trap.queue_free()
			return
		var triggered := false
		for n in get_tree().get_nodes_in_group("enemies"):
			if n is Node2D and is_instance_valid(n) and n.get("is_dead") != true:
				if (n as Node2D).global_position.distance_to(pos) <= 38.0:
					triggered = true
					deal_combat_damage(n, dmg, false, 0.0, pos)
					EnemyStatusScript.apply_stun(n, 1.1)
					EnemyStatusScript.apply_slow(n, 0.45, 2.5)
		if triggered:
			trap.queue_free()
			return
	if is_instance_valid(trap):
		trap.queue_free()


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
